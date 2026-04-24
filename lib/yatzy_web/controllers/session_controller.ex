defmodule YatzyWeb.SessionController do
  use YatzyWeb, :controller

  alias Yatzy.Accounts
  alias YatzyWeb.UserAuth

  def new(conn, _params) do
    render(conn, :new, error: nil, username: "")
  end

  def create(conn, %{"username" => username, "password" => password}) do
    case Accounts.authenticate(username, password) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Tervetuloa, #{user.username}!")
        |> UserAuth.log_in_user(user)

      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> render(:new, error: "Virheellinen käyttäjänimi tai salasana", username: username)
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Olet kirjautunut ulos.")
    |> UserAuth.log_out_user()
  end
end
