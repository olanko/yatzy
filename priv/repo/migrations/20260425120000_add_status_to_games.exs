defmodule Yatzy.Repo.Migrations.AddStatusToGames do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :status, :string, null: false, default: "active"
    end

    create index(:games, [:status])
  end
end
