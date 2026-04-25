defmodule Yatzy.GamesTest do
  use Yatzy.DataCase, async: false

  alias Yatzy.{Accounts, Games}
  alias Yatzy.Games.{Game, GameScore}

  defp register!(username) do
    {:ok, user} = Accounts.register_user(%{username: username, password: "secret123"})
    user
  end

  defp start!(name, players) do
    {:ok, {game, ids}} = Games.start_game(%{"name" => name}, players)
    {game, ids}
  end

  describe "start_game/2" do
    test "creates a game with one GameScore per player" do
      u = register!("alice")
      players = [%{id: "p1", name: "Alice", user_id: u.id}, %{id: "p2", name: "Bob", user_id: nil}]
      {game, ids} = start!("test", players)

      assert game.name == "test"
      assert game.status == :active
      assert length(game.scores) == 2
      assert Map.has_key?(ids, "p1")
      assert Map.has_key?(ids, "p2")
    end

    test "rolls back on invalid attrs" do
      u = register!("alice")
      players = [%{id: "p1", name: "Alice", user_id: u.id}]
      assert {:error, %Ecto.Changeset{}} = Games.start_game(%{"name" => ""}, players)
      assert Games.list_games() == []
    end
  end

  describe "set_score/3" do
    test "persists a valid score and broadcasts" do
      u = register!("alice")
      {game, _ids} = start!("g", [%{id: "p1", name: "Alice", user_id: u.id}])
      Phoenix.PubSub.subscribe(Yatzy.PubSub, "game:#{game.id}")
      sid = hd(game.scores).id

      assert {:ok, score} = Games.set_score(sid, :ones, 3)
      assert score.ones == 3
      assert_receive {:score_updated, %GameScore{ones: 3}}
    end

    test "rejects unknown category" do
      u = register!("ann")
      {game, _} = start!("g", [%{id: "p1", name: "A", user_id: u.id}])
      sid = hd(game.scores).id
      assert Games.set_score(sid, :nope, 1) == {:error, :invalid_category}
    end
  end

  describe "end_game/1 and cancel_game/1" do
    setup do
      u = register!("ann")
      {game, _} = start!("g", [%{id: "p1", name: "A", user_id: u.id}])
      Phoenix.PubSub.subscribe(Yatzy.PubSub, "game:#{game.id}")
      %{game: game}
    end

    test "end_game flips to :ended and broadcasts", %{game: game} do
      assert {:ok, %Game{status: :ended}} = Games.end_game(game)
      assert_receive {:game_status_changed, :ended}
    end

    test "cancel_game flips to :cancelled and broadcasts", %{game: game} do
      assert {:ok, %Game{status: :cancelled}} = Games.cancel_game(game)
      assert_receive {:game_status_changed, :cancelled}
    end
  end

  describe "player?/2" do
    test "true when user_id matches a score row" do
      u = register!("ann")
      {game, _} = start!("g", [%{id: "p1", name: "A", user_id: u.id}])
      assert Games.player?(game, u)
    end

    test "false for a different user" do
      u = register!("ann")
      other = register!("ben")
      {game, _} = start!("g", [%{id: "p1", name: "A", user_id: u.id}])
      refute Games.player?(game, other)
    end

    test "false for nil user" do
      u = register!("ann")
      {game, _} = start!("g", [%{id: "p1", name: "A", user_id: u.id}])
      refute Games.player?(game, nil)
    end
  end

  describe "remove_player_score/1 and rename_player/2" do
    test "remove_player_score deletes the row" do
      u = register!("ann")
      {game, _} = start!("g", [%{id: "p1", name: "A", user_id: u.id}])
      sid = hd(game.scores).id
      assert {:ok, _} = Games.remove_player_score(sid)
      assert Games.get_game_with_scores!(game.id).scores == []
    end

    test "rename_player updates the name" do
      u = register!("ann")
      {game, _} = start!("g", [%{id: "p1", name: "Old", user_id: u.id}])
      sid = hd(game.scores).id
      assert {:ok, _} = Games.rename_player(sid, "New")
      assert hd(Games.get_game_with_scores!(game.id).scores).name == "New"
    end
  end
end
