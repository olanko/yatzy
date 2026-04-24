defmodule Yatzy.Repo.Migrations.AllowGuestScores do
  use Ecto.Migration

  def change do
    drop table(:game_scores)

    create table(:game_scores) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all)
      add :name, :string, null: false

      add :ones, :integer
      add :twos, :integer
      add :threes, :integer
      add :fours, :integer
      add :fives, :integer
      add :sixes, :integer
      add :pair, :integer
      add :two_pairs, :integer
      add :three_of_a_kind, :integer
      add :four_of_a_kind, :integer
      add :small_straight, :integer
      add :large_straight, :integer
      add :full_house, :integer
      add :chance, :integer
      add :yatzy, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:game_scores, [:game_id])
    create index(:game_scores, [:user_id])
  end
end
