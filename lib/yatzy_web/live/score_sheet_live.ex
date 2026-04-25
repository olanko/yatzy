defmodule YatzyWeb.ScoreSheetLive do
  use YatzyWeb, :live_view

  import YatzyWeb.GameHelpers

  alias Yatzy.{Accounts, Games, ScoreSheet}
  alias Yatzy.Games.{Game, GameScore}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       players: [],
       scores: %{},
       invalid_cells: MapSet.new(),
       game: nil,
       game_type: :regular,
       full_straight_points: 21,
       starting_game: false,
       game_form_error: nil,
       winners: nil,
       subscribed_game_id: nil
     )
     |> assign_users()}
  end

  @impl true
  def handle_params(_params, _uri, %{assigns: %{live_action: :new}} = socket) do
    {:noreply, socket}
  end

  def handle_params(%{"id" => raw_id}, _uri, %{assigns: %{live_action: :play}} = socket) do
    case load_active_game(raw_id) do
      {:ok, game} ->
        {players, scores} = build_state_from_game(game)

        {:noreply,
         socket
         |> assign(
           game: game,
           game_type: game.game_type,
           full_straight_points: game.full_straight_points,
           players: players,
           scores: scores
         )
         |> ensure_subscribed(game)}

      :inactive ->
        {:noreply,
         socket
         |> put_flash(:info, "Peli ei ole enää käynnissä.")
         |> push_navigate(to: ~p"/games/#{raw_id}")}

      :not_found ->
        {:noreply,
         socket
         |> put_flash(:error, "Peliä ei löytynyt.")
         |> push_navigate(to: ~p"/")}
    end
  end

  defp load_active_game(raw_id) do
    with {id, ""} <- Integer.parse(to_string(raw_id)),
         %Game{} = game <- safe_get_game(id) do
      case game.status do
        :active -> {:ok, game}
        _ -> :inactive
      end
    else
      _ -> :not_found
    end
  end

  defp ensure_subscribed(socket, %Game{} = game) do
    current = socket.assigns.subscribed_game_id

    cond do
      current == game.id ->
        socket

      true ->
        if connected?(socket) do
          if current, do: Games.unsubscribe(current)
          Games.subscribe(game.id)
        end

        assign(socket, :subscribed_game_id, game.id)
    end
  end

  defp ensure_unsubscribed(socket) do
    case socket.assigns.subscribed_game_id do
      nil ->
        socket

      id ->
        if connected?(socket), do: Games.unsubscribe(id)
        assign(socket, :subscribed_game_id, nil)
    end
  end

  defp assign_users(socket) do
    assign(socket, :users, Accounts.list_users())
  end

  defp available_users(users, players) do
    taken = for %{user_id: uid} when not is_nil(uid) <- players, into: MapSet.new(), do: uid
    Enum.reject(users, &MapSet.member?(taken, &1.id))
  end

  @impl true
  def handle_event("update_score", %{"player" => pid, "category" => cat, "value" => raw}, socket) do
    cat_atom = String.to_existing_atom(cat)
    parsed = parse_score(raw)

    valid? =
      not is_nil(parsed) and
        ScoreSheet.valid_score?(
          cat_atom,
          parsed,
          socket.assigns.game_type,
          socket.assigns.full_straight_points
        )

    scores =
      Map.update!(socket.assigns.scores, pid, fn ps ->
        case parsed do
          nil -> Map.delete(ps, cat_atom)
          n -> Map.put(ps, cat_atom, n)
        end
      end)

    invalid_cells =
      cond do
        is_nil(parsed) -> MapSet.delete(socket.assigns.invalid_cells, {pid, cat_atom})
        valid? -> MapSet.delete(socket.assigns.invalid_cells, {pid, cat_atom})
        true -> MapSet.put(socket.assigns.invalid_cells, {pid, cat_atom})
      end

    if socket.assigns.game do
      persist_score(socket.assigns, pid, cat_atom, if(valid?, do: parsed, else: nil))
    end

    {:noreply, assign(socket, scores: scores, invalid_cells: invalid_cells)}
  end

  def handle_event("dismiss_winner", _params, socket) do
    case socket.assigns.game do
      %Game{} = game ->
        {:noreply, push_navigate(socket, to: ~p"/games/#{game.id}")}

      _ ->
        {:noreply, assign(socket, :winners, nil)}
    end
  end

  def handle_event("rename_player", %{"player" => pid, "value" => name}, socket) do
    players =
      Enum.map(socket.assigns.players, fn
        %{id: ^pid} = p -> %{p | name: name}
        p -> p
      end)

    {:noreply, assign(socket, :players, players)}
  end

  def handle_event("add_guest", _params, socket) do
    add_player(socket, %{name: "Vieras", user_id: nil})
  end

  def handle_event("add_user_player", %{"user_id" => ""}, socket), do: {:noreply, socket}

  def handle_event("add_user_player", %{"user_id" => user_id_str}, socket) do
    user_id = String.to_integer(user_id_str)

    case Enum.find(socket.assigns.users, &(&1.id == user_id)) do
      nil -> {:noreply, socket}
      user -> add_player(socket, %{name: user.username, user_id: user.id})
    end
  end

  def handle_event("remove_player", %{"player" => pid}, socket) do
    players = Enum.reject(socket.assigns.players, &(&1.id == pid))
    scores = Map.delete(socket.assigns.scores, pid)

    invalid_cells =
      Enum.reduce(socket.assigns.invalid_cells, MapSet.new(), fn
        {^pid, _}, acc -> acc
        cell, acc -> MapSet.put(acc, cell)
      end)

    {:noreply, assign(socket, players: players, scores: scores, invalid_cells: invalid_cells)}
  end

  def handle_event("reset", _params, socket) do
    scores = Map.new(socket.assigns.players, fn p -> {p.id, %{}} end)
    {:noreply, assign(socket, scores: scores, invalid_cells: MapSet.new())}
  end

  def handle_event("set_game_type", %{"game_type" => gt}, socket) do
    if socket.assigns.game do
      {:noreply, socket}
    else
      game_type =
        case gt do
          "maxi" -> :maxi
          _ -> :regular
        end

      invalid_cells =
        revalidate_cells(socket.assigns.scores, game_type, socket.assigns.full_straight_points)

      {:noreply, assign(socket, game_type: game_type, invalid_cells: invalid_cells)}
    end
  end

  def handle_event("set_full_straight_points", %{"points" => raw}, socket) do
    if socket.assigns.game do
      {:noreply, socket}
    else
      points =
        case Integer.parse(to_string(raw)) do
          {n, ""} when n in [21, 30] -> n
          _ -> 21
        end

      invalid_cells = revalidate_cells(socket.assigns.scores, socket.assigns.game_type, points)

      {:noreply, assign(socket, full_straight_points: points, invalid_cells: invalid_cells)}
    end
  end

  def handle_event("open_start_game", _params, socket) do
    {:noreply, assign(socket, :starting_game, true)}
  end

  def handle_event("cancel_start_game", _params, socket) do
    {:noreply, assign(socket, starting_game: false, game_form_error: nil)}
  end

  def handle_event("start_game", %{"game" => attrs}, socket) do
    attrs =
      attrs
      |> Map.put("game_type", to_string(socket.assigns.game_type))
      |> Map.put("full_straight_points", to_string(socket.assigns.full_straight_points))

    case Games.start_game(attrs, socket.assigns.players) do
      {:ok, {game, _score_ids}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Peli aloitettu: #{game.name}")
         |> push_navigate(to: ~p"/play/#{game.id}")}

      {:error, %Ecto.Changeset{} = cs} ->
        {:noreply, assign(socket, :game_form_error, format_changeset_error(cs))}
    end
  end

  def handle_event("update_game_comment", %{"value" => raw}, socket) do
    case socket.assigns.game do
      nil ->
        {:noreply, socket}

      game ->
        comment = String.trim(raw)
        comment = if comment == "", do: nil, else: comment

        case Games.update_game_comment(game, comment) do
          {:ok, updated} -> {:noreply, assign(socket, :game, updated)}
          {:error, _} -> {:noreply, socket}
        end
    end
  end

  def handle_event("end_game", _params, socket) do
    case socket.assigns.game do
      nil ->
        {:noreply, socket}

      game ->
        Games.end_game(game)

        winners =
          find_winners(
            socket.assigns.players,
            socket.assigns.scores,
            socket.assigns.invalid_cells,
            socket.assigns.game_type
          )

        {:noreply,
         socket
         |> assign(:game, %{game | status: :ended})
         |> assign(:winners, winners)}
    end
  end

  def handle_event("cancel_game", _params, socket) do
    case socket.assigns.game do
      nil ->
        {:noreply, socket}

      game ->
        Games.cancel_game(game)

        {:noreply,
         socket
         |> ensure_unsubscribed()
         |> put_flash(:info, "Peli peruutettu.")
         |> push_navigate(to: ~p"/games/#{game.id}")}
    end
  end

  @impl true
  def handle_info({:chat_message, _} = msg, socket) do
    if game = socket.assigns.game do
      send_update(YatzyWeb.ChatComponent,
        id: "chat-game-#{game.id}",
        action: msg
      )
    end

    {:noreply, socket}
  end

  def handle_info({:score_updated, _score}, socket) do
    {:noreply, socket}
  end

  def handle_info({:game_status_changed, status}, socket) do
    case socket.assigns.game do
      nil ->
        {:noreply, socket}

      %Game{} = game when status == :cancelled ->
        {:noreply,
         socket
         |> ensure_unsubscribed()
         |> put_flash(:info, "Peli peruutettiin toisesta välilehdestä.")
         |> push_navigate(to: ~p"/games/#{game.id}")}

      game ->
        {:noreply, assign(socket, :game, %{game | status: status})}
    end
  end

  defp safe_get_game(id) do
    Games.get_game_with_scores!(id)
  rescue
    Ecto.NoResultsError -> nil
  end

  defp build_state_from_game(game) do
    players_with_scores =
      Enum.map(game.scores, fn s ->
        local_id = "p#{s.id}"

        player = %{
          id: local_id,
          name: s.name,
          user_id: s.user_id,
          score_id: s.id
        }

        score_map =
          for cat <- GameScore.categories(),
              v = Map.get(s, cat),
              not is_nil(v),
              into: %{},
              do: {cat, v}

        {player, {local_id, score_map}}
      end)

    players = Enum.map(players_with_scores, &elem(&1, 0))
    scores = players_with_scores |> Enum.map(&elem(&1, 1)) |> Map.new()
    {players, scores}
  end

  defp persist_score(assigns, pid, category, value) do
    case Enum.find(assigns.players, &(&1.id == pid)) do
      %{score_id: sid} when not is_nil(sid) ->
        Games.set_score(sid, category, value)

      _ ->
        :ok
    end
  end

  defp add_player(socket, attrs) do
    next_id = "p#{System.unique_integer([:positive])}"
    base = %{id: next_id, name: "Pelaaja", user_id: nil, score_id: nil}
    new_player = Map.merge(base, attrs)

    new_player =
      if game = socket.assigns.game do
        score = Games.add_player_to_game(game.id, new_player)
        %{new_player | score_id: score.id}
      else
        new_player
      end

    players = socket.assigns.players ++ [new_player]
    scores = Map.put(socket.assigns.scores, next_id, %{})
    {:noreply, assign(socket, players: players, scores: scores)}
  end

  defp parse_score(""), do: nil

  defp parse_score(raw) when is_binary(raw) do
    case Integer.parse(String.trim(raw)) do
      {n, ""} when n >= 0 -> n
      _ -> nil
    end
  end

  defp format_changeset_error(%Ecto.Changeset{errors: errors}) do
    errors
    |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
    |> Enum.join(", ")
  end

  defp find_winners(players, scores, invalid_cells, game_type) do
    scored =
      Enum.map(players, fn p ->
        total = ScoreSheet.total(valid_scores(scores[p.id], invalid_cells, p.id), game_type)
        {p, total}
      end)

    top = scored |> Enum.map(&elem(&1, 1)) |> Enum.max(fn -> 0 end)
    winners = scored |> Enum.filter(fn {_, t} -> t == top end) |> Enum.map(&elem(&1, 0))
    %{players: winners, total: top}
  end

  defp valid_scores(player_scores, invalid_cells, pid) do
    Enum.reduce(player_scores || %{}, %{}, fn {cat, val}, acc ->
      if MapSet.member?(invalid_cells, {pid, cat}) do
        acc
      else
        Map.put(acc, cat, val)
      end
    end)
  end

  defp revalidate_cells(scores, game_type, full_straight_points) do
    for {pid, cats} <- scores,
        {cat, val} <- cats,
        not ScoreSheet.valid_score?(cat, val, game_type, full_straight_points),
        into: MapSet.new(),
        do: {pid, cat}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-4">
        <div class="flex items-center justify-between gap-2 flex-wrap">
          <h1 class="text-3xl font-bold">AltistYatzy 🎲</h1>
          <div class="flex gap-2">
            <.link href={~p"/"} class="btn btn-sm btn-ghost">← Etusivu</.link>
            <button
              :if={is_nil(@game)}
              class="btn btn-sm btn-primary"
              phx-click="open_start_game"
              disabled={@players == []}
            >
              Aloita peli
            </button>
            <button
              :if={@game}
              class="btn btn-sm btn-warning"
              phx-click="end_game"
              data-confirm="Lopetetaanko peli? (Tulokset jäävät tietokantaan.)"
            >
              Lopeta peli
            </button>
            <button
              :if={@game}
              class="btn btn-sm btn-error btn-outline"
              phx-click="cancel_game"
              data-confirm="Peruutetaanko peli? Pisteet jäävät tietokantaan, mutta peli merkitään peruutetuksi."
            >
              Peruuta peli
            </button>
            <button class="btn btn-sm btn-ghost" phx-click="reset" data-confirm="Nollataanko pisteet?">
              Nollaa pisteet
            </button>
          </div>
        </div>

        <div
          :if={@winners}
          class="relative overflow-hidden rounded-box border-4 border-warning bg-gradient-to-br from-yellow-100 via-pink-100 to-purple-200 p-6 text-center shadow-2xl"
        >
          <div class="pointer-events-none absolute inset-0 select-none text-4xl leading-none">
            <span class="absolute top-2 left-4 animate-pulse">🎆</span>
            <span class="absolute top-4 right-6 animate-bounce">🎇</span>
            <span class="absolute bottom-3 left-10 animate-bounce">✨</span>
            <span class="absolute bottom-4 right-12 animate-pulse">🎆</span>
            <span class="absolute top-8 left-1/3 animate-bounce">🎉</span>
            <span class="absolute bottom-8 right-1/3 animate-pulse">🎉</span>
          </div>

          <div class="relative space-y-3">
            <div class="text-7xl animate-bounce">🍾</div>
            <h2 class="text-3xl font-extrabold text-purple-800">
              Onnittelut, {Enum.map_join(@winners.players, " & ", & &1.name)}!
            </h2>
            <p class="text-lg text-purple-700">
              Voittajan loppupistemäärä: <strong>{@winners.total}</strong>
            </p>
            <p :if={length(@winners.players) > 1} class="text-sm text-purple-700">
              Tasapeli — kaikki yhtä voitokkaita 🥂
            </p>
            <button class="btn btn-warning mt-2" phx-click="dismiss_winner">
              Sulje
            </button>
          </div>
        </div>

        <div :if={@game} class="alert alert-info">
          <div class="w-full">
            <strong>{@game.name}</strong>
            <span class="text-sm opacity-70">· {@game.played_on}</span>
            <span class={["ml-2", status_badge_class(@game.status)]}>
              {Game.status_label(@game.status)}
            </span>
            <span class="badge badge-outline ml-2">{Game.type_label(@game.game_type)}</span>
            <span :if={@game.game_type == :maxi} class="badge badge-outline ml-1">
              Täyssuora {@game.full_straight_points}
            </span>
            <textarea
              id={"game-comment-#{@game.id}"}
              rows="2"
              class="textarea textarea-bordered textarea-sm w-full mt-2"
              placeholder="Lisää kommentti…"
              phx-blur="update_game_comment"
              phx-debounce="500"
            >{@game.comment}</textarea>
          </div>
        </div>

        <div :if={is_nil(@game)} class="flex flex-wrap items-center gap-4">
          <div class="flex flex-wrap items-center gap-2">
            <span class="text-sm font-medium">Pelityyppi:</span>
            <div class="join">
              <button
                type="button"
                class={[
                  "btn btn-sm join-item",
                  @game_type == :regular && "btn-primary",
                  @game_type != :regular && "btn-outline"
                ]}
                phx-click="set_game_type"
                phx-value-game_type="regular"
              >
                Normaali (5 noppaa)
              </button>
              <button
                type="button"
                class={[
                  "btn btn-sm join-item",
                  @game_type == :maxi && "btn-primary",
                  @game_type != :maxi && "btn-outline"
                ]}
                phx-click="set_game_type"
                phx-value-game_type="maxi"
              >
                Maxi (6 noppaa)
              </button>
            </div>
          </div>

          <div :if={@game_type == :maxi} class="flex flex-wrap items-center gap-2">
            <span class="text-sm font-medium">Täyssuoran pisteet:</span>
            <div class="join">
              <button
                :for={pts <- Game.full_straight_options()}
                type="button"
                class={[
                  "btn btn-sm join-item",
                  @full_straight_points == pts && "btn-primary",
                  @full_straight_points != pts && "btn-outline"
                ]}
                phx-click="set_full_straight_points"
                phx-value-points={pts}
              >
                {pts}
              </button>
            </div>
          </div>
        </div>

        <div :if={@starting_game} class="rounded-box border border-base-300 p-4 space-y-3 bg-base-100">
          <h2 class="font-semibold">Aloita uusi peli</h2>
          <p :if={@game_form_error} class="text-error text-sm">{@game_form_error}</p>
          <form phx-submit="start_game" class="space-y-3">
            <label class="form-control w-full">
              <span class="label-text">Pelin nimi</span>
              <input
                type="text"
                name="game[name]"
                required
                autofocus
                class="input input-bordered w-full"
              />
            </label>
            <label class="form-control w-full">
              <span class="label-text">Kommentti</span>
              <textarea name="game[comment]" rows="2" class="textarea textarea-bordered w-full"></textarea>
            </label>
            <p class="text-xs text-base-content/70">
              Pisteet tallennetaan vain rekisteröityneiden käyttäjien osalta.
            </p>
            <div class="flex gap-2">
              <button type="submit" class="btn btn-primary btn-sm">Aloita</button>
              <button type="button" class="btn btn-ghost btn-sm" phx-click="cancel_start_game">
                Peruuta
              </button>
            </div>
          </form>
        </div>

        <div class="flex flex-col lg:flex-row lg:items-start gap-6 justify-center">
          <.live_component
            :if={@current_user && @game}
            module={YatzyWeb.ChatComponent}
            id={"chat-game-#{@game.id}"}
            scope={{:game, @game.id}}
            current_user={@current_user}
          />

          <aside class="rounded-box border border-base-300 p-4 space-y-3 w-full lg:w-64 shrink-0">
            <h2 class="font-semibold">Pelaajat</h2>
            <ul :if={@players != []} class="divide-y divide-base-300">
              <li :for={p <- @players} class="group flex items-center gap-2 py-1">
                <span :if={p.user_id} class="text-xs" title="Rekisteröitynyt käyttäjä">👤</span>
                <span :if={is_nil(p.user_id)} class="text-xs opacity-50" title="Vieras">·</span>
                <input
                  type="text"
                  class="input input-sm input-ghost flex-1 min-w-0"
                  value={p.name}
                  phx-blur="rename_player"
                  phx-value-player={p.id}
                />
                <button
                  class="btn btn-xs btn-ghost text-error invisible group-hover:visible focus:visible"
                  phx-click="remove_player"
                  phx-value-player={p.id}
                  title="Poista pelaaja"
                >
                  ×
                </button>
              </li>
            </ul>
            <p :if={@players == []} class="text-sm text-base-content/70">
              Ei pelaajia.
            </p>

            <div class="space-y-2 pt-2 border-t border-base-300">
              <% available = available_users(@users, @players) %>
              <form
                :if={available != []}
                phx-change="add_user_player"
                class="flex gap-2"
              >
                <select name="user_id" class="select select-sm select-bordered flex-1">
                  <option value="">+ Lisää käyttäjä…</option>
                  <option :for={u <- available} value={u.id}>{u.username}</option>
                </select>
              </form>
              <button class="btn btn-sm btn-ghost w-full" phx-click="add_guest">
                + Lisää vieras
              </button>
            </div>
          </aside>

          <div :if={@players != []} class="overflow-x-auto">
            <table class="table table-zebra table-fixed rounded-box border border-base-300 w-auto">
              <colgroup>
                <col class="w-40" />
                <col :for={_ <- @players} class="w-24" />
              </colgroup>
              <thead>
                <tr>
                  <th class="text-right">Kategoria</th>
                  <th :for={p <- @players} class="text-center font-semibold truncate">
                    {p.name}
                  </th>
                </tr>
              </thead>

              <tbody>
                <tr :for={{key, label} <- ScoreSheet.upper_categories()}>
                  <th class="text-right font-medium">{label}</th>
                  <td :for={p <- @players} class="p-1">
                    <.score_input
                      player={p}
                      category={key}
                      scores={@scores}
                      invalid_cells={@invalid_cells}
                      disabled={is_nil(@game) or @game.status != :active}
                    />
                  </td>
                </tr>

                <tr class="bg-base-200 font-semibold">
                  <th class="text-right">Välisumma</th>
                  <td :for={p <- @players} class="text-center">
                    {ScoreSheet.upper_subtotal(valid_scores(@scores[p.id], @invalid_cells, p.id))}
                  </td>
                </tr>

                <tr class="bg-base-200 font-semibold">
                  <th class="text-right">
                    Bonus
                    <span class="text-xs opacity-60">({ScoreSheet.bonus_threshold(@game_type)})</span>
                  </th>
                  <td :for={p <- @players} class="text-center">
                    {ScoreSheet.bonus(valid_scores(@scores[p.id], @invalid_cells, p.id), @game_type)}
                  </td>
                </tr>

                <tr :for={{key, label} <- ScoreSheet.lower_categories(@game_type)}>
                  <th class="text-right font-medium">
                    <div>{label}</div>
                    <div :if={ScoreSheet.hint(key)} class="text-xs opacity-60 font-normal">
                      {ScoreSheet.hint(key)}
                    </div>
                  </th>
                  <td :for={p <- @players} class="p-1">
                    <.score_input
                      player={p}
                      category={key}
                      scores={@scores}
                      invalid_cells={@invalid_cells}
                      disabled={is_nil(@game) or @game.status != :active}
                    />
                  </td>
                </tr>

                <tr class="bg-base-200 font-bold text-lg">
                  <th class="text-right">Summa</th>
                  <td :for={p <- @players} class="text-center">
                    {ScoreSheet.total(valid_scores(@scores[p.id], @invalid_cells, p.id), @game_type)}
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

  attr :player, :map, required: true
  attr :category, :atom, required: true
  attr :scores, :map, required: true
  attr :invalid_cells, :any, required: true
  attr :disabled, :boolean, default: false

  defp score_input(assigns) do
    value = get_in(assigns.scores, [assigns.player.id, assigns.category])
    invalid? = MapSet.member?(assigns.invalid_cells, {assigns.player.id, assigns.category})
    assigns = assign(assigns, value: value, invalid?: invalid?)

    ~H"""
    <input
      type="number"
      min="0"
      disabled={@disabled}
      class={[
        "input input-sm w-full min-w-0 text-center",
        @invalid? && "input-error border-2",
        @disabled && "opacity-50 cursor-not-allowed"
      ]}
      value={@value}
      phx-blur="update_score"
      phx-value-player={@player.id}
      phx-value-category={@category}
    />
    """
  end
end
