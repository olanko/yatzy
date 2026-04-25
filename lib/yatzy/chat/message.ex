defmodule Yatzy.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_messages" do
    belongs_to(:game, Yatzy.Games.Game)
    belongs_to(:user, Yatzy.Accounts.User)
    field(:body, :string)

    timestamps(type: :utc_datetime)
  end

  def changeset(msg, attrs) do
    msg
    |> cast(attrs, [:game_id, :user_id, :body])
    |> update_change(:body, &normalize_body/1)
    |> validate_required([:user_id, :body])
    |> validate_length(:body, min: 1, max: 2000)
  end

  defp normalize_body(nil), do: nil
  defp normalize_body(body), do: String.trim(body)
end
