defmodule YatzyWeb.RegistrationLive do
  use YatzyWeb, :live_view

  alias Yatzy.Accounts
  alias Yatzy.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    changeset = User.registration_changeset(%User{}, %{})

    {:ok,
     socket
     |> assign(:page_title, "Lisää käyttäjä")
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"user" => attrs}, socket) do
    changeset =
      %User{}
      |> User.registration_changeset(attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"user" => attrs}, socket) do
    case Accounts.register_user(attrs) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Käyttäjä #{user.username} luotu.")
         |> push_navigate(to: ~p"/leaderboard")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = cs) do
    assign(socket, :form, to_form(cs, as: "user"))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-sm space-y-4">
        <h1 class="text-2xl font-bold">Lisää käyttäjä</h1>

        <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-3">
          <label class="form-control w-full">
            <span class="label-text">Käyttäjänimi</span>
            <input
              type="text"
              name={@form[:username].name}
              value={Phoenix.HTML.Form.normalize_value("text", @form[:username].value)}
              required
              minlength="3"
              maxlength="60"
              autofocus
              class="input input-bordered w-full"
            />
            <span :if={msg = @form[:username].errors |> List.first()} class="text-error text-sm">
              {translate_error(msg)}
            </span>
          </label>

          <label class="form-control w-full">
            <span class="label-text">Salasana</span>
            <input
              type="password"
              name={@form[:password].name}
              value=""
              required
              minlength="6"
              class="input input-bordered w-full"
            />
            <span :if={msg = @form[:password].errors |> List.first()} class="text-error text-sm">
              {translate_error(msg)}
            </span>
          </label>

          <div class="flex gap-2">
            <button type="submit" class="btn btn-primary">Luo</button>
            <.link href={~p"/"} class="btn btn-ghost">Peruuta</.link>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end
end
