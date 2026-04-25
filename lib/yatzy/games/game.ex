defmodule Yatzy.Games.Game do
  use Ecto.Schema
  import Ecto.Changeset

  @game_types [:regular, :maxi]
  @full_straight_options [21, 30]

  def game_types, do: @game_types
  def full_straight_options, do: @full_straight_options

  def type_label(:regular), do: "5 noppaa"
  def type_label(:maxi), do: "Maxi (6 noppaa)"

  schema "games" do
    field :name, :string
    field :comment, :string
    field :played_on, :date
    field :game_type, Ecto.Enum, values: @game_types, default: :regular
    field :full_straight_points, :integer, default: 21

    has_many :scores, Yatzy.Games.GameScore

    timestamps(type: :utc_datetime)
  end

  def changeset(game, attrs) do
    game
    |> cast(attrs, [:name, :comment, :played_on, :game_type, :full_straight_points])
    |> validate_required([:name, :played_on, :game_type, :full_straight_points])
    |> validate_inclusion(:game_type, @game_types)
    |> validate_inclusion(:full_straight_points, @full_straight_options)
    |> validate_length(:name, max: 200)
  end
end
