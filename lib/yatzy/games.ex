defmodule Yatzy.Games do
  @moduledoc "Games + per-player score persistence (registered users + guests)."

  import Ecto.Query
  alias Yatzy.Games.{Game, GameScore}
  alias Yatzy.Repo

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
      Repo.get!(GameScore, score_id)
      |> GameScore.changeset(%{category => value})
      |> Repo.update()
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
