defmodule Yatzy.ScoreSheet do
  @upper_categories [
    {:ones, "Ykköset"},
    {:twos, "Kakkoset"},
    {:threes, "Kolmoset"},
    {:fours, "Neloset"},
    {:fives, "Viitoset"},
    {:sixes, "Kuutoset"}
  ]

  @regular_lower_categories [
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

  @maxi_lower_categories [
    {:pair, "Pari"},
    {:two_pairs, "Kaksi paria"},
    {:three_pairs, "Kolme paria"},
    {:three_of_a_kind, "Kolme samaa"},
    {:four_of_a_kind, "Neljä samaa"},
    {:five_of_a_kind, "Viisi samaa"},
    {:small_straight, "Pieni suora"},
    {:large_straight, "Iso suora"},
    {:full_straight, "Täyssuora"},
    {:full_house, "Täyskäsi"},
    {:house, "Talo"},
    {:sauna, "Sauna"},
    {:chance, "Sattuma"},
    {:yatzy, "Yatzy"}
  ]

  @bonus_threshold_regular 63
  @bonus_threshold_maxi 84
  @bonus_amount_regular 50
  @bonus_amount_maxi 100

  @hints %{
    house: "4 samaa + pari",
    sauna: "3 + 3 (kaksi eri kolmosta)",
    full_house: "3 samaa + pari (mökki)"
  }

  def hint(category), do: Map.get(@hints, category)

  # Full house = 3a + 2b for distinct dice values 1..6.
  @full_house_set for(a <- 1..6, b <- 1..6, a != b, do: 3 * a + 2 * b)
                  |> Enum.uniq()
                  |> Enum.sort()

  # Three pairs = 2(a + b + c) for three distinct values a < b < c in 1..6.
  @three_pairs_set for(a <- 1..6, b <- 1..6, c <- 1..6, a < b and b < c, do: 2 * (a + b + c))
                   |> Enum.uniq()
                   |> Enum.sort()

  # House (4 + 2) = 4a + 2b for distinct dice values 1..6.
  @house_set for(a <- 1..6, b <- 1..6, a != b, do: 4 * a + 2 * b)
             |> Enum.uniq()
             |> Enum.sort()

  # Sauna (3 + 3) = 3(a + b) for distinct dice values a < b in 1..6.
  @sauna_set for(a <- 1..6, b <- 1..6, a < b, do: 3 * (a + b))
             |> Enum.uniq()
             |> Enum.sort()

  @doc """
  Returns true if the score is valid for the given category, game type, and
  full-straight points option. Zero is always valid.
  """
  def valid_score?(category, value, game_type \\ :regular, full_straight_points \\ 21)

  def valid_score?(_category, 0, _game_type, _fsp), do: true

  def valid_score?(:ones, n, :regular, _), do: n in [1, 2, 3, 4, 5]
  def valid_score?(:ones, n, :maxi, _), do: n in [1, 2, 3, 4, 5, 6]
  def valid_score?(:twos, n, :regular, _), do: n in [2, 4, 6, 8, 10]
  def valid_score?(:twos, n, :maxi, _), do: n in [2, 4, 6, 8, 10, 12]
  def valid_score?(:threes, n, :regular, _), do: n in [3, 6, 9, 12, 15]
  def valid_score?(:threes, n, :maxi, _), do: n in [3, 6, 9, 12, 15, 18]
  def valid_score?(:fours, n, :regular, _), do: n in [4, 8, 12, 16, 20]
  def valid_score?(:fours, n, :maxi, _), do: n in [4, 8, 12, 16, 20, 24]
  def valid_score?(:fives, n, :regular, _), do: n in [5, 10, 15, 20, 25]
  def valid_score?(:fives, n, :maxi, _), do: n in [5, 10, 15, 20, 25, 30]
  def valid_score?(:sixes, n, :regular, _), do: n in [6, 12, 18, 24, 30]
  def valid_score?(:sixes, n, :maxi, _), do: n in [6, 12, 18, 24, 30, 36]

  def valid_score?(:pair, n, _, _), do: n in [2, 4, 6, 8, 10, 12]
  def valid_score?(:two_pairs, n, _, _), do: n in [6, 8, 10, 12, 14, 16, 18, 20, 22]
  def valid_score?(:three_of_a_kind, n, _, _), do: n in [3, 6, 9, 12, 15, 18]
  def valid_score?(:four_of_a_kind, n, _, _), do: n in [4, 8, 12, 16, 20, 24]
  def valid_score?(:small_straight, n, _, _), do: n == 15
  def valid_score?(:large_straight, n, _, _), do: n == 20
  def valid_score?(:full_house, n, _, _), do: n in @full_house_set

  def valid_score?(:chance, n, :regular, _), do: n in 5..30
  def valid_score?(:chance, n, :maxi, _), do: n in 6..36

  def valid_score?(:yatzy, n, :regular, _), do: n == 50
  def valid_score?(:yatzy, n, :maxi, _), do: n == 100

  def valid_score?(:three_pairs, n, :maxi, _), do: n in @three_pairs_set
  def valid_score?(:five_of_a_kind, n, :maxi, _), do: n in [5, 10, 15, 20, 25, 30]
  def valid_score?(:house, n, :maxi, _), do: n in @house_set
  def valid_score?(:sauna, n, :maxi, _), do: n in @sauna_set
  def valid_score?(:full_straight, n, :maxi, fsp) when fsp in [21, 30], do: n == fsp

  def valid_score?(_, _, _, _), do: false

  def upper_categories, do: @upper_categories

  def lower_categories(:regular), do: @regular_lower_categories
  def lower_categories(:maxi), do: @maxi_lower_categories

  def all_categories(game_type), do: @upper_categories ++ lower_categories(game_type)

  def category_keys(game_type), do: Enum.map(all_categories(game_type), &elem(&1, 0))
  def upper_keys, do: Enum.map(@upper_categories, &elem(&1, 0))
  def lower_keys(game_type), do: Enum.map(lower_categories(game_type), &elem(&1, 0))

  def bonus_threshold(:regular), do: @bonus_threshold_regular
  def bonus_threshold(:maxi), do: @bonus_threshold_maxi

  def bonus_amount(:regular), do: @bonus_amount_regular
  def bonus_amount(:maxi), do: @bonus_amount_maxi

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
  Bonus is awarded when the upper subtotal reaches the threshold for the given game type.
  """
  def bonus(scores, game_type) when is_map(scores) do
    if upper_subtotal(scores) >= bonus_threshold(game_type),
      do: bonus_amount(game_type),
      else: 0
  end

  @doc """
  Total = sum of all filled-in categories valid for the game type + bonus.
  """
  def total(scores, game_type) when is_map(scores) do
    filled =
      category_keys(game_type)
      |> Enum.map(&Map.get(scores, &1))
      |> Enum.reject(&is_nil/1)
      |> Enum.sum()

    filled + bonus(scores, game_type)
  end
end
