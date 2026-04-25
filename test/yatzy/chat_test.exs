defmodule Yatzy.ChatTest do
  use Yatzy.DataCase, async: false

  alias Yatzy.{Accounts, Chat, Games}

  defp register!(username) do
    {:ok, user} = Accounts.register_user(%{username: username, password: "secret123"})
    user
  end

  defp start!(name, user) do
    {:ok, {game, _}} = Games.start_game(%{"name" => name}, [%{id: "p1", name: name, user_id: user.id}])
    game
  end

  describe "create_message/3 and list_messages/2 (per-game)" do
    test "inserts and lists in chronological order, oldest first" do
      u = register!("alice")
      g = start!("g", u)

      {:ok, _m1} = Chat.create_message({:game, g.id}, u, "hello")
      {:ok, _m2} = Chat.create_message({:game, g.id}, u, "world")

      msgs = Chat.list_messages({:game, g.id})
      assert Enum.map(msgs, & &1.body) == ["hello", "world"]
    end

    test "preloads :user" do
      u = register!("ann")
      g = start!("g", u)
      {:ok, _} = Chat.create_message({:game, g.id}, u, "hi")
      [msg] = Chat.list_messages({:game, g.id})
      assert msg.user.username == "ann"
    end

    test "before_id paginates older messages" do
      u = register!("ann")
      g = start!("g", u)
      msgs = for i <- 1..5, do: elem(Chat.create_message({:game, g.id}, u, "m#{i}"), 1)
      cursor = List.last(msgs).id

      page = Chat.list_messages({:game, g.id}, limit: 100, before_id: cursor)
      assert length(page) == 4
      assert List.last(page).id == Enum.at(msgs, 3).id
    end

    test "scope filters: per-game does not see global, and vice versa" do
      u = register!("ann")
      g = start!("g", u)
      {:ok, _} = Chat.create_message({:game, g.id}, u, "in-game")
      {:ok, _} = Chat.create_message(:global, u, "in-lobby")

      assert Enum.map(Chat.list_messages({:game, g.id}), & &1.body) == ["in-game"]
      assert Enum.map(Chat.list_messages(:global), & &1.body) == ["in-lobby"]
    end
  end

  describe "create_message/3 broadcasts" do
    test "per-game broadcast on game topic and on chat:recent" do
      u = register!("ann")
      g = start!("g", u)

      Phoenix.PubSub.subscribe(Yatzy.PubSub, Chat.topic({:game, g.id}))
      Chat.subscribe_recent()

      {:ok, _} = Chat.create_message({:game, g.id}, u, "hi")

      assert_receive {:chat_message, %{body: "hi"}}
      assert_receive {:chat_message, %{body: "hi"}}
    end

    test "global broadcast on chat:global and chat:recent" do
      u = register!("ann")
      Chat.subscribe(:global)
      Chat.subscribe_recent()

      {:ok, _} = Chat.create_message(:global, u, "lobby")

      assert_receive {:chat_message, %{body: "lobby"}}
      assert_receive {:chat_message, %{body: "lobby"}}
    end
  end

  describe "list_recent_messages/1" do
    test "returns newest first across all rooms" do
      u = register!("ann")
      g = start!("g", u)
      {:ok, _} = Chat.create_message({:game, g.id}, u, "first")
      {:ok, _} = Chat.create_message(:global, u, "second")

      [newest | _] = Chat.list_recent_messages(limit: 10)
      assert newest.body == "second"
    end

    test "paginates with before_id" do
      u = register!("ann")
      msgs = for i <- 1..5, do: elem(Chat.create_message(:global, u, "m#{i}"), 1)
      cursor = List.first(Chat.list_recent_messages(limit: 1)).id

      older = Chat.list_recent_messages(limit: 10, before_id: cursor)
      assert length(older) == 4
      assert hd(older).id == Enum.at(msgs, 3).id
    end
  end
end
