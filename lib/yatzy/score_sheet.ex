defmodule Yatzy.ScoreSheet do
  @upper_categories [
    {:ones, "Ykköset"},
    {:twos, "Kakkoset"},
    {:threes, "Kolmoset"},
    {:fours, "Neloset"},
    {:fives, "Viitoset"},
    {:sixes, "Kuutoset"}
  ]

  @lower_categories [
    {:pair, "Pari"},
    {:two_pairs, "Kaksi paria"},
    {:three_of_a_kind, "Kolme samaa"},
    {:four_of_a_kind, "Neljä samaa"},
    {:small_straight, "Pieni suora"},
    {:large_straight, "Iso suora"},
    {:full_house, "Täyskäsi"},
    {:chance, "Sattuma"},
    {:yatzy, "Yatzy"}
  ]

  @bonus_threshold 63
  @bonus_amount 50

  # Valid full-house sums = 3a + 2b for a, b ∈ 1..6, a ≠ b.
  @full_house_sums for a <- 1..6, b <- 1..6, a != b, do: 3 * a + 2 * b
  @full_house_set Enum.uniq(@full_house_sums) |> Enum.sort()

  @doc "Returns true if the score is valid for the given category. Zero is always valid."
  def valid_score?(_category, 0), do: true

  def valid_score?(:ones, n), do: n in [1, 2, 3, 4, 5]
  def valid_score?(:twos, n), do: n in [2, 4, 6, 8, 10]
  def valid_score?(:threes, n), do: n in [3, 6, 9, 12, 15]
  def valid_score?(:fours, n), do: n in [4, 8, 12, 16, 20]
  def valid_score?(:fives, n), do: n in [5, 10, 15, 20, 25]
  def valid_score?(:sixes, n), do: n in [6, 12, 18, 24, 30]
  def valid_score?(:pair, n), do: n in [2, 4, 6, 8, 10, 12]
  def valid_score?(:two_pairs, n), do: n in [6, 8, 10, 12, 14, 16, 18, 20, 22]
  def valid_score?(:three_of_a_kind, n), do: n in [3, 6, 9, 12, 15, 18]
  def valid_score?(:four_of_a_kind, n), do: n in [4, 8, 12, 16, 20, 24]
  def valid_score?(:small_straight, n), do: n == 15
  def valid_score?(:large_straight, n), do: n == 20
  def valid_score?(:full_house, n), do: n in @full_house_set
  def valid_score?(:chance, n), do: n in 5..30
  def valid_score?(:yatzy, n), do: n == 50
  def valid_score?(_, _), do: false

  def upper_categories, do: @upper_categories
  def lower_categories, do: @lower_categories
  def all_categories, do: @upper_categories ++ @lower_categories

  def category_keys, do: Enum.map(all_categories(), &elem(&1, 0))
  def upper_keys, do: Enum.map(@upper_categories, &elem(&1, 0))
  def lower_keys, do: Enum.map(@lower_categories, &elem(&1, 0))

  def bonus_threshold, do: @bonus_threshold
  def bonus_amount, do: @bonus_amount

  @doc """
  Sum of the upper section scores for a single column. Nil entries count as 0.
  """
  def upper_subtotal(scores) when is_map(scores) do
    upper_keys()
    |> Enum.map(&Map.get(scores, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.sum()
  end

  @doc """
  Bonus is awarded when the upper subtotal reaches the threshold.
  """
  def bonus(scores) when is_map(scores) do
    if upper_subtotal(scores) >= @bonus_threshold, do: @bonus_amount, else: 0
  end

  @doc """
  Total = sum of all filled-in categories + bonus.
  """
  def total(scores) when is_map(scores) do
    filled =
      category_keys()
      |> Enum.map(&Map.get(scores, &1))
      |> Enum.reject(&is_nil/1)
      |> Enum.sum()

    filled + bonus(scores)
  end
end
