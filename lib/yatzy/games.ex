defmodule Yatzy.Games do
  @moduledoc "Games + per-player score persistence (registered users + guests)."

  import Ecto.Query
  alias Yatzy.Games.{Game, GameScore}
  alias Yatzy.Repo

  def topic(game_id), do: "game:#{game_id}"

  def subscribe(game_id), do: Phoenix.PubSub.subscribe(Yatzy.PubSub, topic(game_id))
  def unsubscribe(game_id), do: Phoenix.PubSub.unsubscribe(Yatzy.PubSub, topic(game_id))

  defp broadcast(game_id, msg),
    do: Phoenix.PubSub.broadcast(Yatzy.PubSub, topic(game_id), msg)

  @doc """
  Start a new game and create one score row per player.
  `players` is a list of maps with `:name` and optional `:user_id`.
  Returns `{:ok, game, score_id_by_local_player_id}` or `{:error, changeset}`.
  """
  def start_game(attrs, players) when is_list(players) do
    attrs = Map.put_new_lazy(attrs, "played_on", &Date.utc_today/0)

    Repo.transaction(fn ->
      with {:ok, game} <- %Game{} |> Game.changeset(attrs) |> Repo.insert() do
        ids =
          for p <- players, into: %{} do
            {:ok, score} =
              %GameScore{}
              |> GameScore.changeset(%{
                game_id: game.id,
                user_id: p[:user_id],
                name: p.name
              })
              |> Repo.insert()

            {p.id, score.id}
          end

        {Repo.preload(game, :scores), ids}
      else
        {:error, cs} -> Repo.rollback(cs)
      end
    end)
  end

  @doc "Create a score row for a player added mid-game."
  def add_player_to_game(game_id, %{name: name} = player) do
    %GameScore{}
    |> GameScore.changeset(%{
      game_id: game_id,
      user_id: player[:user_id],
      name: name
    })
    |> Repo.insert!()
  end

  @doc "Update one category on a score row by its id."
  def set_score(score_id, category, value) when is_atom(category) do
    if category in GameScore.categories() do
      score = Repo.get!(GameScore, score_id)

      case score |> GameScore.changeset(%{category => value}) |> Repo.update() do
        {:ok, updated} ->
          broadcast(updated.game_id, {:score_updated, updated})
          {:ok, updated}

        other ->
          other
      end
    else
      {:error, :invalid_category}
    end
  end

  def delete_game!(id) do
    Repo.get!(Game, id) |> Repo.delete!()
  end

  def update_game_comment(%Game{} = game, comment) do
    game
    |> Game.changeset(%{"comment" => comment})
    |> Repo.update()
  end

  @doc "Mark a game as ended. Broadcasts on the game topic."
  def end_game(%Game{} = game), do: set_status(game, :ended)

  @doc "Mark a game as cancelled. Broadcasts on the game topic."
  def cancel_game(%Game{} = game), do: set_status(game, :cancelled)

  defp set_status(%Game{} = game, status)
       when status in [:waiting, :active, :ended, :cancelled] do
    case game |> Game.changeset(%{"status" => to_string(status)}) |> Repo.update() do
      {:ok, updated} ->
        broadcast(updated.id, {:game_status_changed, status})
        {:ok, updated}

      other ->
        other
    end
  end

  def list_games(types \\ Game.game_types()) do
    types = Enum.to_list(types)

    from(g in Game, where: g.game_type in ^types, order_by: [desc: g.inserted_at])
    |> Repo.all()
  end

  def get_game_with_scores!(id) do
    Game
    |> Repo.get!(id)
    |> Repo.preload(scores: from(s in GameScore, order_by: s.id))
  end
end
