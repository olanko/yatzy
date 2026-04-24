defmodule YatzyWeb.LeaderboardLive do
  use YatzyWeb, :live_view

  alias Yatzy.{Locale, Stats}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Tilastot")
     |> assign(:rows, Stats.leaderboard())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-4 max-w-4xl mx-auto">
        <div class="flex items-center justify-between">
          <h1 class="text-3xl font-bold">Tilastot</h1>
          <.link href={~p"/"} class="btn btn-sm btn-ghost">← Takaisin</.link>
        </div>

        <p :if={@rows == []} class="text-base-content/70">
          Ei rekisteröityjä pelaajia.
        </p>

        <div :if={@rows != []} class="overflow-x-auto rounded-box border border-base-300">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Pelaaja</th>
                <th class="text-right">Pelejä</th>
                <th class="text-right">Voittoja</th>
                <th class="text-right">Keskiarvo</th>
                <th class="text-right">Paras</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={r <- @rows}>
                <td>
                  <.link navigate={~p"/users/#{r.user.id}"} class="link link-hover font-semibold">
                    {r.user.username}
                  </.link>
                </td>
                <td class="text-right">{r.games_played}</td>
                <td class="text-right">{r.wins}</td>
                <td class="text-right">{format_avg(r.avg)}</td>
                <td class="text-right font-semibold">{r.max && r.max.total}</td>
                <td class="text-sm text-base-content/70 whitespace-nowrap">
                  <.link :if={r.max} navigate={~p"/games/#{r.max.game.id}"} class="link link-hover">
                    {Locale.format_date(r.max.game.played_on)}
                  </.link>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_avg(nil), do: "–"
  defp format_avg(n), do: :erlang.float_to_binary(n, decimals: 1)
end
