defmodule Yatzy.NameGeneratorTest do
  use ExUnit.Case, async: true

  alias Yatzy.NameGenerator

  describe "word lists" do
    test "at least 100 adjectives and 100 nouns" do
      assert length(NameGenerator.adjectives()) >= 100
      assert length(NameGenerator.nouns()) >= 100
    end

    test "all words are non-empty lowercase strings" do
      for word <- NameGenerator.adjectives() ++ NameGenerator.nouns() do
        assert is_binary(word)
        assert byte_size(word) > 0
        assert String.downcase(word) == word
      end
    end
  end

  describe "generate/0" do
    test "returns adjective-noun-NN string" do
      for _ <- 1..50 do
        name = NameGenerator.generate()
        assert [adj, noun, n] = String.split(name, "-")
        assert adj in NameGenerator.adjectives()
        assert noun in NameGenerator.nouns()
        {n_int, ""} = Integer.parse(n)
        assert n_int >= 1
      end
    end

    test "produces variety across many calls" do
      names = for _ <- 1..200, do: NameGenerator.generate()
      # 100 * 100 * many = lots of combos; 200 calls should yield mostly unique
      assert length(Enum.uniq(names)) > 150
    end
  end
end
