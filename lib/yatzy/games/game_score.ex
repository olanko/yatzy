defmodule Yatzy.Games.GameScore do
  use Ecto.Schema
  import Ecto.Changeset

  @categories ~w(ones twos threes fours fives sixes pair two_pairs three_of_a_kind
                 four_of_a_kind small_straight large_straight full_house chance yatzy)a

  def categories, do: @categories

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

    timestamps(type: :utc_datetime)
  end

  def changeset(score, attrs) do
    score
    |> cast(attrs, [:game_id, :user_id, :name | @categories])
    |> validate_required([:game_id, :name])
  end
end
