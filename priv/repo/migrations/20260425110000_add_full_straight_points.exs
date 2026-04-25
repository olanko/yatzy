defmodule Yatzy.Repo.Migrations.AddFullStraightPoints do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :full_straight_points, :integer, null: false, default: 21
    end
  end
end
