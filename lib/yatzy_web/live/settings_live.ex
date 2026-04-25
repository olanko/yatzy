defmodule YatzyWeb.SettingsLive do
  use YatzyWeb, :live_view

  alias Yatzy.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, "Omat asetukset")
     |> assign_username_form(Accounts.change_user_username(user))
     |> assign_password_form(Accounts.change_user_password(user))}
  end

  @impl true
  def handle_event("validate_username", %{"user" => attrs}, socket) do
    cs =
      socket.assigns.current_user
      |> Accounts.change_user_username(attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign_username_form(socket, cs)}
  end

  def handle_event("update_username", %{"user" => attrs}, socket) do
    case Accounts.update_username(socket.assigns.current_user, attrs) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:current_user, user)
         |> put_flash(:info, "Käyttäjänimi päivitetty.")
         |> assign_username_form(Accounts.change_user_username(user))}

      {:error, cs} ->
        {:noreply, assign_username_form(socket, cs)}
    end
  end

  def handle_event("update_password", %{"user" => attrs}, socket) do
    %{"current_password" => current} = attrs

    case Accounts.update_user_password(socket.assigns.current_user, current, attrs) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:current_user, user)
         |> put_flash(:info, "Salasana päivitetty.")
         |> assign_password_form(Accounts.change_user_password(user))}

      {:error, cs} ->
        {:noreply, assign_password_form(socket, cs)}
    end
  end

  defp assign_username_form(socket, %Ecto.Changeset{} = cs) do
    assign(socket, :username_form, to_form(cs, as: "user"))
  end

  defp assign_password_form(socket, %Ecto.Changeset{} = cs) do
    assign(socket, :password_form, to_form(cs, as: "user"))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-md space-y-6">
        <h1 class="text-2xl font-bold">Omat asetukset</h1>

        <section class="space-y-3">
          <h2 class="font-semibold">Käyttäjänimi</h2>
          <.form
            for={@username_form}
            phx-change="validate_username"
            phx-submit="update_username"
            class="space-y-3"
          >
            <label class="form-control w-full">
              <input
                type="text"
                name={@username_form[:username].name}
                value={Phoenix.HTML.Form.normalize_value("text", @username_form[:username].value)}
                required
                minlength="3"
                maxlength="60"
                class="input input-bordered w-full"
              />
              <span
                :if={msg = @username_form[:username].errors |> List.first()}
                class="text-error text-sm"
              >
                {translate_error(msg)}
              </span>
            </label>
            <button type="submit" class="btn btn-primary">Tallenna nimi</button>
          </.form>
        </section>

        <section class="space-y-3">
          <h2 class="font-semibold">Vaihda salasana</h2>
          <.form for={@password_form} phx-submit="update_password" class="space-y-3">
            <label class="form-control w-full">
              <span class="label-text">Nykyinen salasana</span>
              <input
                type="password"
                name="user[current_password]"
                required
                class="input input-bordered w-full"
              />
              <span
                :if={msg = @password_form[:current_password].errors |> List.first()}
                class="text-error text-sm"
              >
                {translate_error(msg)}
              </span>
            </label>

            <label class="form-control w-full">
              <span class="label-text">Uusi salasana</span>
              <input
                type="password"
                name={@password_form[:password].name}
                required
                minlength="6"
                class="input input-bordered w-full"
              />
              <span
                :if={msg = @password_form[:password].errors |> List.first()}
                class="text-error text-sm"
              >
                {translate_error(msg)}
              </span>
            </label>

            <label class="form-control w-full">
              <span class="label-text">Vahvista uusi salasana</span>
              <input
                type="password"
                name="user[password_confirmation]"
                required
                class="input input-bordered w-full"
              />
            </label>

            <button type="submit" class="btn btn-primary">Tallenna salasana</button>
          </.form>
        </section>

        <.link href={~p"/"} class="btn btn-ghost">← Etusivu</.link>
      </div>
    </Layouts.app>
    """
  end
end
