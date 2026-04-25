defmodule Yatzy.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages) do
      add :game_id, references(:games, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :nilify_all)
      add :body, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chat_messages, [:game_id, :inserted_at])
    create index(:chat_messages, [:user_id])
  end
end
