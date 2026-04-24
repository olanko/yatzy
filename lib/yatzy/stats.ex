defmodule Yatzy.Stats do
  @moduledoc "Aggregate statistics computed from game_scores."

  import Ecto.Query
  alias Yatzy.Accounts.User
  alias Yatzy.Games.GameScore
  alias Yatzy.Repo
  alias Yatzy.ScoreSheet

  @doc """
  Leaderboard for registered users:
    %{user, games_played, max: %{total, game}, avg, wins}
  Sorted by wins desc, then avg desc.
  """
  def leaderboard do
    rows = load_user_rows()
    games_by_id = group_games(rows)

    User
    |> Repo.all()
    |> Enum.map(fn u ->
      user_rows = Enum.filter(rows, &(&1.user_id == u.id))
      totals = Enum.map(user_rows, &row_total/1)

      max =
        case user_rows do
          [] -> nil
          _ -> highest_row(user_rows)
        end

      %{
        user: u,
        games_played: length(user_rows),
        max: max && %{total: row_total(max), game: max.game},
        avg: avg(totals),
        wins: count_wins(u.id, games_by_id)
      }
    end)
    |> Enum.sort_by(&{-(&1.wins || 0), -(&1.avg || 0)})
  end

  @doc "Top N scores for a user, each with the game."
  def top_scores(user_id, limit \\ 10) do
    user_rows(user_id)
    |> Enum.map(fn r -> %{total: row_total(r), game: r.game} end)
    |> Enum.sort_by(& &1.total, :desc)
    |> Enum.take(limit)
  end

  @doc "Average total score for a user, or nil."
  def avg_score(user_id) do
    user_rows(user_id) |> Enum.map(&row_total/1) |> avg()
  end

  @doc """
  Head-to-head against every opponent the user has played alongside (registered).
  Returns list sorted by games_played desc:
    %{opponent, games, wins, losses, ties, win_pct}
  """
  def head_to_head(user_id) do
    rows = load_user_rows()
    games_by_id = group_games(rows)

    rows
    |> Enum.filter(&(&1.user_id == user_id))
    |> Enum.flat_map(fn my_row ->
      game_rows = Map.get(games_by_id, my_row.game_id, [])
      my_total = row_total(my_row)

      for opp_row <- game_rows,
          opp_row.user_id && opp_row.user_id != user_id,
          do: {opp_row.user_id, compare(my_total, row_total(opp_row))}
    end)
    |> Enum.group_by(fn {opp_id, _} -> opp_id end, fn {_, result} -> result end)
    |> Enum.map(fn {opp_id, results} ->
      wins = Enum.count(results, &(&1 == :win))
      losses = Enum.count(results, &(&1 == :loss))
      ties = Enum.count(results, &(&1 == :tie))
      decisive = wins + losses
      win_pct = if decisive == 0, do: nil, else: wins / decisive * 100

      %{
        opponent: Repo.get!(User, opp_id),
        games: length(results),
        wins: wins,
        losses: losses,
        ties: ties,
        win_pct: win_pct
      }
    end)
    |> Enum.sort_by(& &1.games, :desc)
  end

  # ── helpers ────────────────────────────────────────────────────────────────

  defp load_user_rows do
    from(s in GameScore, where: not is_nil(s.user_id), preload: [:game])
    |> Repo.all()
  end

  defp user_rows(user_id) do
    from(s in GameScore, where: s.user_id == ^user_id, preload: [:game])
    |> Repo.all()
  end

  defp group_games(rows) do
    # Need ALL rows for each game (incl. guests) for win calculations
    game_ids = rows |> Enum.map(& &1.game_id) |> Enum.uniq()

    from(s in GameScore, where: s.game_id in ^game_ids, preload: [:game])
    |> Repo.all()
    |> Enum.group_by(& &1.game_id)
  end

  defp row_total(%GameScore{} = row) do
    map =
      for cat <- GameScore.categories(),
          v = Map.get(row, cat),
          not is_nil(v),
          into: %{},
          do: {cat, v}

    ScoreSheet.total(map)
  end

  defp highest_row(rows), do: Enum.max_by(rows, &row_total/1, fn -> nil end)

  defp avg([]), do: nil
  defp avg(totals), do: Enum.sum(totals) / length(totals)

  defp count_wins(user_id, games_by_id) do
    games_by_id
    |> Map.values()
    |> Enum.count(fn rows ->
      my = Enum.find(rows, &(&1.user_id == user_id))

      if my do
        my_total = row_total(my)
        max_total = rows |> Enum.map(&row_total/1) |> Enum.max()
        my_total == max_total and my_total > 0
      else
        false
      end
    end)
  end

  defp compare(a, b) when a > b, do: :win
  defp compare(a, b) when a < b, do: :loss
  defp compare(_, _), do: :tie
end
