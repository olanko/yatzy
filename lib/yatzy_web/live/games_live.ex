defmodule YatzyWeb.GamesLive do
  use YatzyWeb, :live_view

  alias Yatzy.{Games, Locale}
  alias Yatzy.Games.Game

  @impl true
  def mount(_params, _session, socket) do
    enabled_types = MapSet.new(Game.game_types())

    {:ok,
     socket
     |> assign(:page_title, "Pelihistoria")
     |> assign(:enabled_types, enabled_types)
     |> assign(:games, Games.list_games(enabled_types))}
  end

  @impl true
  def handle_event("toggle_type", %{"type" => raw}, socket) do
    type = String.to_existing_atom(raw)

    enabled_types =
      if MapSet.member?(socket.assigns.enabled_types, type) do
        MapSet.delete(socket.assigns.enabled_types, type)
      else
        MapSet.put(socket.assigns.enabled_types, type)
      end

    {:noreply,
     socket
     |> assign(:enabled_types, enabled_types)
     |> assign(:games, Games.list_games(enabled_types))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-4 max-w-3xl mx-auto">
        <div class="flex items-center justify-between">
          <h1 class="text-3xl font-bold">Pelihistoria</h1>
          <.link href={~p"/"} class="btn btn-sm btn-ghost">← Takaisin</.link>
        </div>

        <.game_type_filter enabled_types={@enabled_types} />

        <p :if={@games == []} class="text-base-content/70">
          Ei pelejä valituilla pelityypeillä.
        </p>

        <ul :if={@games != []} class="divide-y divide-base-300 rounded-box border border-base-300">
          <li :for={g <- @games}>
            <.link
              navigate={~p"/games/#{g.id}"}
              class="block p-4 hover:bg-base-200 flex items-center justify-between gap-3"
            >
              <div class="min-w-0">
                <div class="flex items-center gap-2 flex-wrap">
                  <span class="font-semibold truncate">{g.name}</span>
                  <span class="badge badge-outline badge-sm">{Game.type_label(g.game_type)}</span>
                </div>
                <div :if={g.comment && g.comment != ""} class="text-sm text-base-content/70">
                  {g.comment}
                </div>
              </div>
              <div class="text-sm text-base-content/70 text-right whitespace-nowrap">
                {Locale.format_datetime(g.inserted_at)}
              </div>
            </.link>
          </li>
        </ul>
      </div>
    </Layouts.app>
    """
  end
end
