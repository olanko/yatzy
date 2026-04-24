defmodule Yatzy.Games.Game do
  use Ecto.Schema
  import Ecto.Changeset

  schema "games" do
    field :name, :string
    field :comment, :string
    field :played_on, :date

    has_many :scores, Yatzy.Games.GameScore

    timestamps(type: :utc_datetime)
  end

  def changeset(game, attrs) do
    game
    |> cast(attrs, [:name, :comment, :played_on])
    |> validate_required([:name, :played_on])
    |> validate_length(:name, max: 200)
  end
end
