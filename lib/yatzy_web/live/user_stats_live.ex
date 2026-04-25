defmodule YatzyWeb.UserStatsLive do
  use YatzyWeb, :live_view

  alias Yatzy.Accounts
  alias Yatzy.{Locale, Stats}
  alias Yatzy.Games.Game

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Accounts.get_user(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Käyttäjää ei löydy.")
         |> push_navigate(to: ~p"/leaderboard")}

      user ->
        enabled_types = MapSet.new(Game.game_types())

        {:ok,
         socket
         |> assign(:page_title, user.username)
         |> assign(:user, user)
         |> assign(:enabled_types, enabled_types)
         |> assign_stats(enabled_types)}
    end
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
     |> assign_stats(enabled_types)}
  end

  defp assign_stats(socket, enabled_types) do
    user_id = socket.assigns.user.id

    socket
    |> assign(:top_scores, Stats.top_scores(user_id, 10, enabled_types))
    |> assign(:avg, Stats.avg_score(user_id, enabled_types))
    |> assign(:h2h, Stats.head_to_head(user_id, enabled_types))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-6 max-w-3xl mx-auto">
        <div class="flex items-center justify-between">
          <h1 class="text-3xl font-bold">{@user.username}</h1>
          <.link href={~p"/leaderboard"} class="btn btn-sm btn-ghost">← Tilastot</.link>
        </div>

        <.game_type_filter enabled_types={@enabled_types} />

        <section class="space-y-2">
          <h2 class="text-xl font-semibold">Yhteenveto</h2>
          <div class="stats stats-vertical sm:stats-horizontal shadow w-full">
            <div class="stat">
              <div class="stat-title">Pelejä</div>
              <div class="stat-value text-2xl">{length(@top_scores)}</div>
            </div>
            <div class="stat">
              <div class="stat-title">Keskiarvo</div>
              <div class="stat-value text-2xl">{format_avg(@avg)}</div>
            </div>
            <div class="stat">
              <div class="stat-title">Paras</div>
              <div class="stat-value text-2xl">
                {(@top_scores |> List.first() || %{total: "–"}).total}
              </div>
            </div>
          </div>
        </section>

        <section class="space-y-2">
          <h2 class="text-xl font-semibold">Top 10 pisteet</h2>
          <p :if={@top_scores == []} class="text-base-content/70">Ei vielä pelejä.</p>
          <div :if={@top_scores != []} class="overflow-x-auto rounded-box border border-base-300">
            <table class="table table-zebra">
              <thead>
                <tr>
                  <th class="w-12">#</th>
                  <th class="text-right">Pisteet</th>
                  <th>Päiväys</th>
                  <th>Peli</th>
                  <th>Kommentti</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={{row, idx} <- Enum.with_index(@top_scores, 1)}>
                  <td>{idx}</td>
                  <td class="text-right font-semibold">{row.total}</td>
                  <td>{Locale.format_date(row.game.played_on)}</td>
                  <td>
                    <.link navigate={~p"/games/#{row.game.id}"} class="link link-hover">
                      {row.game.name}
                    </.link>
                  </td>
                  <td class="text-sm text-base-content/70">{row.game.comment}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <section class="space-y-2">
          <h2 class="text-xl font-semibold">Vastakkain muiden kanssa</h2>
          <p :if={@h2h == []} class="text-base-content/70">
            Ei pelejä muiden rekisteröityneiden kanssa.
          </p>
          <div :if={@h2h != []} class="overflow-x-auto rounded-box border border-base-300">
            <table class="table table-zebra">
              <thead>
                <tr>
                  <th>Vastustaja</th>
                  <th class="text-right">Pelejä</th>
                  <th class="text-right">Voittoja</th>
                  <th class="text-right">Tappioita</th>
                  <th class="text-right">Tasapelejä</th>
                  <th class="text-right">Voitto-%</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={r <- @h2h}>
                  <td>
                    <.link navigate={~p"/users/#{r.opponent.id}"} class="link link-hover">
                      {r.opponent.username}
                    </.link>
                  </td>
                  <td class="text-right">{r.games}</td>
                  <td class="text-right">{r.wins}</td>
                  <td class="text-right">{r.losses}</td>
                  <td class="text-right">{r.ties}</td>
                  <td class="text-right">{format_pct(r.win_pct)}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp format_avg(nil), do: "–"
  defp format_avg(n), do: :erlang.float_to_binary(n, decimals: 1)

  defp format_pct(nil), do: "–"
  defp format_pct(n), do: "#{:erlang.float_to_binary(n, decimals: 0)} %"
end
