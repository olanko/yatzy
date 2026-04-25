defmodule YatzyWeb.UsersLive do
  use YatzyWeb, :live_view

  alias Yatzy.{Accounts, Locale, Presence}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Yatzy.PubSub, Presence.topic())
    end

    {:ok,
     socket
     |> assign(:page_title, "Käyttäjät")
     |> assign(:users, Accounts.list_users())
     |> assign(:online, online_user_ids())}
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, :online, online_user_ids())}
  end

  defp online_user_ids do
    Presence.list(Presence.topic())
    |> Map.keys()
    |> Enum.map(&parse_int/1)
    |> Enum.reject(&is_nil/1)
    |> MapSet.new()
  end

  defp parse_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp parse_int(_), do: nil

  defp last_login_label(nil), do: "Ei kirjautunut"
  defp last_login_label(%DateTime{} = dt), do: Locale.format_datetime(dt)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-4 max-w-2xl mx-auto">
        <div class="flex items-center justify-between">
          <h1 class="text-3xl font-bold">Käyttäjät</h1>
          <.link href={~p"/users/new"} class="btn btn-sm btn-primary">+ Lisää käyttäjä</.link>
        </div>

        <ul class="divide-y divide-base-300 rounded-box border border-base-300">
          <li :for={u <- @users}>
            <.link
              navigate={~p"/users/#{u.id}"}
              class="block p-3 hover:bg-base-200 flex items-center gap-3"
            >
              <span
                class={[
                  "h-2.5 w-2.5 rounded-full shrink-0",
                  MapSet.member?(@online, u.id) && "bg-success",
                  !MapSet.member?(@online, u.id) && "bg-base-300"
                ]}
                title={if MapSet.member?(@online, u.id), do: "Linjoilla", else: "Ei linjoilla"}
              />
              <span class="font-medium flex-1">{u.username}</span>
              <span class="text-xs text-base-content/70">
                {last_login_label(u.last_login_at)}
              </span>
            </.link>
          </li>
        </ul>
      </div>
    </Layouts.app>
    """
  end
end
