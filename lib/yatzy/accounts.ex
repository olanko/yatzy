defmodule Yatzy.Accounts do
  @moduledoc "User accounts context."

  alias Yatzy.Accounts.User
  alias Yatzy.Repo

  def get_user(id), do: Repo.get(User, id)

  def list_users do
    import Ecto.Query
    Repo.all(from u in User, order_by: u.username)
  end

  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: username)
  end

  def change_user_username(%User{} = user, attrs \\ %{}) do
    User.username_changeset(user, attrs)
  end

  def update_username(%User{} = user, attrs) do
    user
    |> User.username_changeset(attrs)
    |> Repo.update()
  end

  def change_user_password(%User{} = user, attrs \\ %{}) do
    User.password_changeset(user, attrs)
  end

  def update_user_password(%User{} = user, current_password, attrs) do
    if User.valid_password?(user, current_password) do
      user
      |> User.password_changeset(attrs)
      |> Repo.update()
    else
      changeset =
        user
        |> User.password_changeset(attrs)
        |> Ecto.Changeset.add_error(:current_password, "on virheellinen")
        |> Map.put(:action, :update)

      {:error, changeset}
    end
  end

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def authenticate(username, password) do
    user = get_user_by_username(username)

    cond do
      user && User.valid_password?(user, password) -> {:ok, user}
      user -> {:error, :invalid_password}
      true -> {:error, :not_found}
    end
  end
end
