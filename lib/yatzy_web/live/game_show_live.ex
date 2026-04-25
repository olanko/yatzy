defmodule YatzyWeb.GameShowLive do
  use YatzyWeb, :live_view

  import YatzyWeb.GameHelpers

  alias Yatzy.{Games, Locale, ScoreSheet}
  alias Yatzy.Games.{Game, GameScore}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    game = Games.get_game_with_scores!(id)
    ranks = compute_ranks(game.scores, game.game_type)

    if connected?(socket) and game.status == :active do
      Games.subscribe(game.id)
    end

    {:ok,
     socket
     |> assign(:page_title, game.name)
     |> assign(:game, game)
     |> assign(:ranks, ranks)}
  end

  @impl true
  def handle_event("delete_game", _params, socket) do
    Games.delete_game!(socket.assigns.game.id)

    {:noreply,
     socket
     |> put_flash(:info, "Peli poistettu.")
     |> push_navigate(to: ~p"/games")}
  end

  @impl true
  def handle_info({:chat_message, _} = msg, socket) do
    send_update(YatzyWeb.ChatComponent,
      id: "chat-game-#{socket.assigns.game.id}",
      action: msg
    )

    {:noreply, socket}
  end

  def handle_info({:score_updated, %GameScore{} = score}, socket) do
    {:noreply, apply_score_update(socket, score)}
  end

  def handle_info({:game_status_changed, status}, socket) do
    {:noreply, apply_status_change(socket, status)}
  end

  defp apply_score_update(socket, %GameScore{} = score) do
    game = socket.assigns.game

    scores =
      Enum.map(game.scores, fn s ->
        if s.id == score.id, do: score, else: s
      end)

    game = %{game | scores: scores}
    ranks = compute_ranks(scores, game.game_type)

    socket
    |> assign(:game, game)
    |> assign(:ranks, ranks)
  end

  defp apply_status_change(socket, status) do
    game = %{socket.assigns.game | status: status}

    if status in [:ended, :cancelled] do
      Games.unsubscribe(game.id)
    end

    assign(socket, :game, game)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-4">
        <div class="flex items-center justify-between flex-wrap gap-2">
          <div>
            <h1 class="text-3xl font-bold">{@game.name}</h1>
            <p class="text-sm text-base-content/70">
              {Locale.format_datetime(@game.inserted_at)}
              <span class={["ml-2", status_badge_class(@game.status)]}>
                {Game.status_label(@game.status)}
              </span>
              <span class="badge badge-outline badge-sm ml-2">
                {Game.type_label(@game.game_type)}
              </span>
              <span :if={@game.game_type == :maxi} class="badge badge-outline badge-sm ml-1">
                Täyssuora {@game.full_straight_points}
              </span>
            </p>
            <p :if={@game.comment && @game.comment != ""} class="text-sm">{@game.comment}</p>
          </div>
          <div class="flex gap-2">
            <.link
              :if={@game.status == :active}
              navigate={~p"/play/#{@game.id}"}
              class="btn btn-sm btn-primary"
            >
              Jatka pelaamista
            </.link>
            <button
              class="btn btn-sm btn-error btn-outline"
              phx-click="delete_game"
              data-confirm="Haluatko varmasti poistaa pelin? Tätä ei voi peruuttaa."
            >
              Poista peli
            </button>
            <.link href={~p"/"} class="btn btn-sm btn-ghost">← Pelit</.link>
          </div>
        </div>

        <div :if={@game.scores == []} class="text-base-content/70">
          Ei pelaajia tässä pelissä.
        </div>

        <div class="flex flex-col lg:flex-row lg:items-start gap-6">
          <.live_component
            :if={@current_user}
            module={YatzyWeb.ChatComponent}
            id={"chat-game-#{@game.id}"}
            scope={{:game, @game.id}}
            current_user={@current_user}
          />

          <div :if={@game.scores != []} class="overflow-x-auto flex-1">
            <table class="table table-zebra table-fixed rounded-box border border-base-300 w-auto mx-auto">
              <colgroup>
                <col class="w-40" />
                <col :for={_ <- @game.scores} class="w-24" />
              </colgroup>
              <thead>
                <tr>
                  <th class="text-right">Kategoria</th>
                  <th :for={s <- @game.scores} class="text-center font-semibold truncate">
                    <div class="flex items-center justify-center gap-1">
                      <span class="text-base-content/60">{@ranks[s.id]}.</span>
                      <span :if={s.user_id} title="Rekisteröitynyt käyttäjä">👤</span>
                      <.link
                        :if={s.user_id}
                        navigate={~p"/users/#{s.user_id}"}
                        class="link link-hover"
                      >
                        {s.name}
                      </.link>
                      <span :if={is_nil(s.user_id)}>{s.name}</span>
                    </div>
                  </th>
                </tr>
              </thead>

              <tbody>
                <tr :for={{key, label} <- ScoreSheet.upper_categories()}>
                  <th class="text-right font-medium">{label}</th>
                  <td :for={s <- @game.scores} class="text-center">
                    {render_cell(s, key)}
                  </td>
                </tr>

                <tr class="bg-base-200 font-semibold">
                  <th class="text-right">Välisumma</th>
                  <td :for={s <- @game.scores} class="text-center">
                    {ScoreSheet.upper_subtotal(score_map(s))}
                  </td>
                </tr>

                <tr class="bg-base-200 font-semibold">
                  <th class="text-right">
                    Bonus
                    <span class="text-xs opacity-60">
                      ({ScoreSheet.bonus_threshold(@game.game_type)})
                    </span>
                  </th>
                  <td :for={s <- @game.scores} class="text-center">
                    {ScoreSheet.bonus(score_map(s), @game.game_type)}
                  </td>
                </tr>

                <tr :for={{key, label} <- ScoreSheet.lower_categories(@game.game_type)}>
                  <th class="text-right font-medium">
                    <div>{label}</div>
                    <div :if={ScoreSheet.hint(key)} class="text-xs opacity-60 font-normal">
                      {ScoreSheet.hint(key)}
                    </div>
                  </th>
                  <td :for={s <- @game.scores} class="text-center">
                    {render_cell(s, key)}
                  </td>
                </tr>

                <tr class="bg-base-200 font-bold text-lg">
                  <th class="text-right">Summa</th>
                  <td :for={s <- @game.scores} class="text-center">
                    {ScoreSheet.total(score_map(s), @game.game_type)}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp compute_ranks(scores, game_type) do
    scored = Enum.map(scores, fn s -> {s.id, ScoreSheet.total(score_map(s), game_type)} end)
    sorted_totals = scored |> Enum.map(&elem(&1, 1)) |> Enum.sort(:desc)

    Map.new(scored, fn {id, total} ->
      rank = Enum.find_index(sorted_totals, &(&1 == total)) + 1
      {id, rank}
    end)
  end

  defp render_cell(%GameScore{} = score, category) do
    case Map.get(score, category) do
      nil -> "–"
      n -> n
    end
  end

  defp score_map(%GameScore{} = score) do
    for cat <- GameScore.categories(), into: %{} do
      {cat, Map.get(score, cat)}
    end
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end
end
