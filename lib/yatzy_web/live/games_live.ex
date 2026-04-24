defmodule YatzyWeb.GamesLive do
  use YatzyWeb, :live_view

  alias Yatzy.{Games, Locale}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Pelihistoria")
     |> assign(:games, Games.list_games())}
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

        <p :if={@games == []} class="text-base-content/70">Yhtään peliä ei ole vielä tallennettu.</p>

        <ul :if={@games != []} class="divide-y divide-base-300 rounded-box border border-base-300">
          <li :for={g <- @games}>
            <.link
              navigate={~p"/games/#{g.id}"}
              class="block p-4 hover:bg-base-200 flex items-center justify-between"
            >
              <div>
                <div class="font-semibold">{g.name}</div>
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
