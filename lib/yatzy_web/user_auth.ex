defmodule YatzyWeb.UserAuth do
  @moduledoc """
  Session-based authentication helpers: plug to load `current_user` into
  conn assigns and a LiveView on_mount hook that mirrors the same.
  """

  use YatzyWeb, :verified_routes
  import Plug.Conn
  import Phoenix.Controller

  alias Yatzy.Accounts

  @session_key :user_id

  def log_in_user(conn, user) do
    conn
    |> renew_session()
    |> put_session(@session_key, user.id)
    |> redirect(to: ~p"/")
  end

  def log_out_user(conn) do
    conn
    |> renew_session()
    |> redirect(to: ~p"/")
  end

  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, @session_key)
    user = user_id && Accounts.get_user(user_id)
    assign(conn, :current_user, user)
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "Sinun täytyy kirjautua sisään.")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "Sinun täytyy kirjautua sisään.")
        |> Phoenix.LiveView.redirect(to: ~p"/login")

      {:halt, socket}
    end
  end

  defp mount_current_user(socket, session) do
    socket =
      Phoenix.Component.assign_new(socket, :current_user, fn ->
        with id when not is_nil(id) <- session["user_id"] do
          Accounts.get_user(id)
        end
      end)

    track_presence(socket)
    socket
  end

  defp track_presence(%{assigns: %{current_user: %{id: id, username: username}}} = socket) do
    if Phoenix.LiveView.connected?(socket) do
      try do
        Yatzy.Presence.track(
          self(),
          Yatzy.Presence.topic(),
          to_string(id),
          %{username: username}
        )
      rescue
        # Presence process not started (e.g. stale dev supervision tree).
        # Mount must not fail because of this; just skip tracking.
        ArgumentError -> :ok
      end
    end
  end

  defp track_presence(_socket), do: :ok

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
