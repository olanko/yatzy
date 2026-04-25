defmodule Yatzy.StatsTest do
  use Yatzy.DataCase, async: false

  alias Yatzy.{Accounts, Games, Stats}

  defp register!(username) do
    {:ok, user} = Accounts.register_user(%{username: username, password: "secret123"})
    user
  end

  defp game!(name, players, opts) do
    {:ok, {game, ids}} = Games.start_game(%{"name" => name}, players)

    if scores = opts[:scores] do
      for {pid, cat_map} <- scores, {cat, val} <- cat_map do
        Games.set_score(ids[pid], cat, val)
      end
    end

    case opts[:status] do
      :ended -> Games.end_game(game)
      :cancelled -> Games.cancel_game(game)
      _ -> :ok
    end

    game
  end

  describe "leaderboard/1" do
    test "counts wins per registered user" do
      a = register!("alice")
      b = register!("bob")

      # alice wins
      _ =
        game!("g1",
          [%{id: "p1", name: "Alice", user_id: a.id}, %{id: "p2", name: "Bob", user_id: b.id}],
          scores: %{"p1" => %{ones: 5}, "p2" => %{ones: 3}}
        )

      board = Stats.leaderboard()
      alice = Enum.find(board, &(&1.user.id == a.id))
      bob = Enum.find(board, &(&1.user.id == b.id))

      assert alice.wins == 1
      assert bob.wins == 0
      assert alice.games_played == 1
      # leaderboard sorts wins desc; alice should be ahead
      assert hd(board).user.id == a.id
    end

    test "excludes cancelled games" do
      a = register!("ann")

      _ =
        game!("g1", [%{id: "p1", name: "A", user_id: a.id}],
          scores: %{"p1" => %{ones: 5}},
          status: :cancelled
        )

      board = Stats.leaderboard()
      alice = Enum.find(board, &(&1.user.id == a.id))
      assert alice.games_played == 0
      assert alice.wins == 0
    end
  end

  describe "top_scores/3" do
    test "returns user's highest games, sorted desc" do
      a = register!("ann")

      _ =
        game!("g1", [%{id: "p1", name: "A", user_id: a.id}],
          scores: %{"p1" => %{ones: 1}}
        )

      _ =
        game!("g2", [%{id: "p1", name: "A", user_id: a.id}],
          scores: %{"p1" => %{ones: 5}}
        )

      [first, second] = Stats.top_scores(a.id, 5)
      assert first.total >= second.total
    end
  end

  describe "head_to_head/2" do
    test "tallies wins/losses against each opponent" do
      a = register!("ann")
      b = register!("ben")

      _ =
        game!("g1",
          [%{id: "p1", name: "A", user_id: a.id}, %{id: "p2", name: "B", user_id: b.id}],
          scores: %{"p1" => %{ones: 5}, "p2" => %{ones: 3}}
        )

      _ =
        game!("g2",
          [%{id: "p1", name: "A", user_id: a.id}, %{id: "p2", name: "B", user_id: b.id}],
          scores: %{"p1" => %{ones: 1}, "p2" => %{ones: 5}}
        )

      [%{opponent: opp, wins: w, losses: l, games: g}] = Stats.head_to_head(a.id)
      assert opp.id == b.id
      assert w == 1
      assert l == 1
      assert g == 2
    end
  end

  describe "avg_score/2" do
    test "averages user's totals" do
      a = register!("ann")

      _ =
        game!("g1", [%{id: "p1", name: "A", user_id: a.id}],
          scores: %{"p1" => %{ones: 5}}
        )

      _ =
        game!("g2", [%{id: "p1", name: "A", user_id: a.id}],
          scores: %{"p1" => %{ones: 1}}
        )

      assert Stats.avg_score(a.id) == 3.0
    end

    test "nil when no games" do
      a = register!("ann")
      assert Stats.avg_score(a.id) == nil
    end
  end
end
