defmodule Yatzy.ScoreSheetTest do
  use ExUnit.Case, async: true

  alias Yatzy.ScoreSheet

  describe "valid_score?/4 — upper section" do
    test "ones accepts only sums of ones" do
      assert ScoreSheet.valid_score?(:ones, 0)
      for n <- 1..5, do: assert(ScoreSheet.valid_score?(:ones, n, :regular))
      refute ScoreSheet.valid_score?(:ones, 6, :regular)
      assert ScoreSheet.valid_score?(:ones, 6, :maxi)
    end

    test "twos / threes / fours / fives / sixes follow the multiplier rule" do
      assert ScoreSheet.valid_score?(:twos, 10, :regular)
      refute ScoreSheet.valid_score?(:twos, 11, :regular)
      assert ScoreSheet.valid_score?(:fives, 25, :regular)
      assert ScoreSheet.valid_score?(:sixes, 36, :maxi)
      refute ScoreSheet.valid_score?(:sixes, 36, :regular)
    end
  end

  describe "valid_score?/4 — lower section" do
    test "pair / two_pairs / three / four / chance" do
      assert ScoreSheet.valid_score?(:pair, 12)
      refute ScoreSheet.valid_score?(:pair, 13)
      assert ScoreSheet.valid_score?(:two_pairs, 22)
      refute ScoreSheet.valid_score?(:two_pairs, 23)
      assert ScoreSheet.valid_score?(:three_of_a_kind, 18)
      assert ScoreSheet.valid_score?(:four_of_a_kind, 24)
      assert ScoreSheet.valid_score?(:chance, 30, :regular)
      refute ScoreSheet.valid_score?(:chance, 31, :regular)
      assert ScoreSheet.valid_score?(:chance, 36, :maxi)
    end

    test "small / large straight are fixed totals" do
      assert ScoreSheet.valid_score?(:small_straight, 15)
      refute ScoreSheet.valid_score?(:small_straight, 14)
      assert ScoreSheet.valid_score?(:large_straight, 20)
      refute ScoreSheet.valid_score?(:large_straight, 19)
    end

    test "yatzy is 50 / 100 by game type" do
      assert ScoreSheet.valid_score?(:yatzy, 50, :regular)
      refute ScoreSheet.valid_score?(:yatzy, 100, :regular)
      assert ScoreSheet.valid_score?(:yatzy, 100, :maxi)
    end

    test "full_house = 3a + 2b for distinct dice values" do
      # 3*5 + 2*6 = 27, valid
      assert ScoreSheet.valid_score?(:full_house, 27)
      # 3*6 + 2*6 = 30 — but a == b, invalid
      refute ScoreSheet.valid_score?(:full_house, 30)
    end
  end

  describe "valid_score?/4 — Maxi-only categories" do
    test "three_pairs = 2(a+b+c) for three distinct values" do
      # 2*(1+2+3) = 12
      assert ScoreSheet.valid_score?(:three_pairs, 12, :maxi)
      # 2*(2+3+4) = 18
      assert ScoreSheet.valid_score?(:three_pairs, 18, :maxi)
      # 11 is odd — cannot equal 2*(a+b+c)
      refute ScoreSheet.valid_score?(:three_pairs, 11, :maxi)
      # 2*(4+5+6) = 30 is the max for three distinct dice 1..6; 32 is impossible
      refute ScoreSheet.valid_score?(:three_pairs, 32, :maxi)
    end

    test "five_of_a_kind / house / sauna / full_straight" do
      assert ScoreSheet.valid_score?(:five_of_a_kind, 30, :maxi)
      refute ScoreSheet.valid_score?(:five_of_a_kind, 31, :maxi)
      assert ScoreSheet.valid_score?(:full_straight, 21, :maxi, 21)
      assert ScoreSheet.valid_score?(:full_straight, 30, :maxi, 30)
      refute ScoreSheet.valid_score?(:full_straight, 21, :maxi, 30)
    end
  end

  describe "valid_score?/4 — zero is always valid" do
    test "zero accepted for any category" do
      for cat <- ScoreSheet.category_keys(:regular) do
        assert ScoreSheet.valid_score?(cat, 0, :regular)
      end

      for cat <- ScoreSheet.category_keys(:maxi) do
        assert ScoreSheet.valid_score?(cat, 0, :maxi)
      end
    end
  end

  describe "upper_subtotal/1 and bonus/2" do
    test "subtotal sums upper section, ignoring nil" do
      scores = %{ones: 3, twos: 6, threes: 9, fours: nil, fives: 15, sixes: 18}
      assert ScoreSheet.upper_subtotal(scores) == 51
    end

    test "regular bonus awarded at 63" do
      scores = %{ones: 3, twos: 6, threes: 9, fours: 12, fives: 15, sixes: 18}
      assert ScoreSheet.upper_subtotal(scores) == 63
      assert ScoreSheet.bonus(scores, :regular) == 50
    end

    test "regular bonus not awarded under 63" do
      scores = %{ones: 3, twos: 6, threes: 9, fours: 12, fives: 15, sixes: 12}
      assert ScoreSheet.upper_subtotal(scores) == 57
      assert ScoreSheet.bonus(scores, :regular) == 0
    end

    test "maxi bonus awarded at 84" do
      scores = %{ones: 4, twos: 8, threes: 12, fours: 16, fives: 20, sixes: 24}
      assert ScoreSheet.upper_subtotal(scores) == 84
      assert ScoreSheet.bonus(scores, :maxi) == 100
    end
  end

  describe "total/2" do
    test "regular total = upper + lower + bonus" do
      scores = %{
        ones: 3,
        twos: 6,
        threes: 9,
        fours: 12,
        fives: 15,
        sixes: 18,
        pair: 12,
        chance: 28,
        yatzy: 50
      }

      # upper = 63 → bonus 50; lower = 12 + 28 + 50 = 90; total = 63 + 90 + 50 = 203
      assert ScoreSheet.total(scores, :regular) == 203
    end

    test "maxi categories ignored under regular" do
      scores = %{ones: 1, three_pairs: 12}
      assert ScoreSheet.total(scores, :regular) == 1
      assert ScoreSheet.total(scores, :maxi) == 13
    end
  end

  describe "category lists" do
    test "regular categories include yatzy and chance, not maxi-only" do
      keys = ScoreSheet.category_keys(:regular)
      assert :yatzy in keys
      assert :chance in keys
      refute :three_pairs in keys
      refute :house in keys
      refute :sauna in keys
      refute :full_straight in keys
    end

    test "maxi categories include the maxi extras" do
      keys = ScoreSheet.category_keys(:maxi)
      for k <- [:three_pairs, :five_of_a_kind, :house, :sauna, :full_straight], do: assert(k in keys)
    end
  end

  describe "hint/1" do
    test "returns Finnish hints for Maxi categories" do
      assert ScoreSheet.hint(:house) =~ "samaa"
      assert ScoreSheet.hint(:sauna) =~ "kolmosta"
      assert ScoreSheet.hint(:full_house) =~ "mökki"
    end

    test "returns nil for categories without a hint" do
      assert ScoreSheet.hint(:ones) == nil
    end
  end
end
