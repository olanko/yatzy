defmodule Yatzy.Repo.Migrations.AddMaxiYatzy do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :game_type, :string, null: false, default: "regular"
    end

    alter table(:game_scores) do
      add :three_pairs, :integer
      add :five_of_a_kind, :integer
      add :house, :integer
      add :sauna, :integer
      add :full_straight, :integer
    end
  end
end
