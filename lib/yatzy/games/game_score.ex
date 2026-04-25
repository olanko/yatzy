defmodule Yatzy.Games.GameScore do
  use Ecto.Schema
  import Ecto.Changeset

  @regular_categories ~w(ones twos threes fours fives sixes pair two_pairs three_of_a_kind
                         four_of_a_kind small_straight large_straight full_house chance yatzy)a

  @maxi_extra_categories ~w(three_pairs five_of_a_kind house sauna full_straight)a

  @categories @regular_categories ++ @maxi_extra_categories

  def categories, do: @categories
  def regular_categories, do: @regular_categories
  def maxi_extra_categories, do: @maxi_extra_categories

  schema "game_scores" do
    belongs_to :game, Yatzy.Games.Game
    belongs_to :user, Yatzy.Accounts.User
    field :name, :string

    field :ones, :integer
    field :twos, :integer
    field :threes, :integer
    field :fours, :integer
    field :fives, :integer
    field :sixes, :integer
    field :pair, :integer
    field :two_pairs, :integer
    field :three_of_a_kind, :integer
    field :four_of_a_kind, :integer
    field :small_straight, :integer
    field :large_straight, :integer
    field :full_house, :integer
    field :chance, :integer
    field :yatzy, :integer

    field :three_pairs, :integer
    field :five_of_a_kind, :integer
    field :house, :integer
    field :sauna, :integer
    field :full_straight, :integer

    timestamps(type: :utc_datetime)
  end

  def changeset(score, attrs) do
    score
    |> cast(attrs, [:game_id, :user_id, :name | @categories])
    |> validate_required([:game_id, :name])
  end
end
