defmodule Yatzy.Games.Game do
  use Ecto.Schema
  import Ecto.Changeset

  @game_types [:regular, :maxi]
  @full_straight_options [21, 30]
  @statuses [:active, :ended, :cancelled]

  def game_types, do: @game_types
  def full_straight_options, do: @full_straight_options
  def statuses, do: @statuses

  def type_label(:regular), do: "5 noppaa"
  def type_label(:maxi), do: "Maxi (6 noppaa)"

  def status_label(:active), do: "Käynnissä"
  def status_label(:ended), do: "Päättynyt"
  def status_label(:cancelled), do: "Peruutettu"

  schema "games" do
    field(:name, :string)
    field(:comment, :string)
    field(:played_on, :date)
    field(:game_type, Ecto.Enum, values: @game_types, default: :regular)
    field(:full_straight_points, :integer, default: 21)
    field(:status, Ecto.Enum, values: @statuses, default: :active)

    has_many(:scores, Yatzy.Games.GameScore)

    timestamps(type: :utc_datetime)
  end

  def changeset(game, attrs) do
    game
    |> cast(attrs, [:name, :comment, :played_on, :game_type, :full_straight_points, :status])
    |> validate_required([:name, :played_on, :game_type, :full_straight_points, :status])
    |> validate_inclusion(:game_type, @game_types)
    |> validate_inclusion(:full_straight_points, @full_straight_options)
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:name, max: 200)
  end
end
