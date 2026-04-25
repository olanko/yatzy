defmodule Yatzy.Chat do
  @moduledoc """
  Chat messages scoped to a room.

  A scope is either `{:game, id}` for per-game chat or `:global` for the future
  global room. Both share the same `chat_messages` table; global messages have
  `game_id IS NULL`.
  """

  import Ecto.Query
  alias Yatzy.Accounts.User
  alias Yatzy.Chat.Message
  alias Yatzy.Repo

  @type scope :: {:game, integer()} | :global

  @recent_topic "chat:recent"

  def topic({:game, id}), do: "game:#{id}"
  def topic(:global), do: "chat:global"

  def subscribe(scope), do: Phoenix.PubSub.subscribe(Yatzy.PubSub, topic(scope))
  def unsubscribe(scope), do: Phoenix.PubSub.unsubscribe(Yatzy.PubSub, topic(scope))

  def subscribe_recent, do: Phoenix.PubSub.subscribe(Yatzy.PubSub, @recent_topic)
  def unsubscribe_recent, do: Phoenix.PubSub.unsubscribe(Yatzy.PubSub, @recent_topic)

  @doc """
  List the most recent messages for the given scope, oldest first, with `:user`
  preloaded for rendering.
  """
  def list_messages(scope, limit \\ 200) do
    Message
    |> scope_filter(scope)
    |> order_by([m], desc: m.inserted_at, desc: m.id)
    |> limit(^limit)
    |> Repo.all()
    |> Repo.preload(:user)
    |> Enum.reverse()
  end

  @doc """
  Recent chat messages from all rooms (global + every game), **newest first**.
  Preloads `:user` and `:game` (`:game` is nil for global messages).

  Options:
    * `:limit` — page size, default 20
    * `:before_id` — return only messages older than this id (for "show more")
  """
  def list_recent_messages(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    before_id = Keyword.get(opts, :before_id)

    query =
      from m in Message,
        order_by: [desc: m.inserted_at, desc: m.id],
        limit: ^limit

    query = if before_id, do: from(m in query, where: m.id < ^before_id), else: query

    query
    |> Repo.all()
    |> Repo.preload([:user, :game])
  end

  @doc """
  Insert a message and broadcast `{:chat_message, msg}` (with `:user` preloaded)
  on the scope topic, plus on the shared "chat:recent" topic for the lobby
  feed. `:game` is preloaded so the feed can show a game-name badge.
  """
  def create_message(scope, %User{} = user, body) do
    attrs =
      scope_to_attrs(scope)
      |> Map.put(:user_id, user.id)
      |> Map.put(:body, body)

    case %Message{} |> Message.changeset(attrs) |> Repo.insert() do
      {:ok, msg} ->
        msg = msg |> Repo.preload(:game) |> Map.put(:user, user)
        Phoenix.PubSub.broadcast(Yatzy.PubSub, topic(scope), {:chat_message, msg})
        Phoenix.PubSub.broadcast(Yatzy.PubSub, @recent_topic, {:chat_message, msg})
        {:ok, msg}

      other ->
        other
    end
  end

  defp scope_filter(query, {:game, id}), do: from(m in query, where: m.game_id == ^id)
  defp scope_filter(query, :global), do: from(m in query, where: is_nil(m.game_id))

  defp scope_to_attrs({:game, id}), do: %{game_id: id}
  defp scope_to_attrs(:global), do: %{game_id: nil}
end
