defmodule YatzyWeb.ScoreSheetLive do
  use YatzyWeb, :live_view

  alias Yatzy.{Accounts, Games, ScoreSheet}
  alias Yatzy.Games.GameScore

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       players: [],
       scores: %{},
       invalid_cells: MapSet.new(),
       game: nil,
       starting_game: false,
       game_form_error: nil,
       winners: nil
     )
     |> assign_users()}
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
    valid? = not is_nil(parsed) and ScoreSheet.valid_score?(cat_atom, parsed)

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
    {:noreply, assign(socket, :winners, nil)}
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

  def handle_event("open_start_game", _params, socket) do
    {:noreply, assign(socket, :starting_game, true)}
  end

  def handle_event("cancel_start_game", _params, socket) do
    {:noreply, assign(socket, starting_game: false, game_form_error: nil)}
  end

  def handle_event("start_game", %{"game" => attrs}, socket) do
    case Games.start_game(attrs, socket.assigns.players) do
      {:ok, {game, score_ids}} ->
        players =
          Enum.map(socket.assigns.players, fn p ->
            Map.put(p, :score_id, Map.fetch!(score_ids, p.id))
          end)

        {:noreply,
         socket
         |> assign(
           game: game,
           players: players,
           starting_game: false,
           game_form_error: nil
         )
         |> put_flash(:info, "Peli aloitettu: #{game.name}")
         |> push_event("save_game", %{game_id: game.id})}

      {:error, %Ecto.Changeset{} = cs} ->
        {:noreply, assign(socket, :game_form_error, format_changeset_error(cs))}
    end
  end

  def handle_event("end_game", _params, socket) do
    winners =
      find_winners(socket.assigns.players, socket.assigns.scores, socket.assigns.invalid_cells)

    {:noreply,
     socket
     |> assign(:game, nil)
     |> assign(:winners, winners)
     |> push_event("clear_game", %{})}
  end

  def handle_event("restore_game", %{"game_id" => raw_id}, socket) do
    with {id, ""} <- Integer.parse(to_string(raw_id)),
         %_{} = game <- safe_get_game(id) do
      {players, scores} = build_state_from_game(game)

      {:noreply, assign(socket, game: game, players: players, scores: scores)}
    else
      _ ->
        {:noreply, push_event(socket, "clear_game", %{})}
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

  defp find_winners(players, scores, invalid_cells) do
    scored =
      Enum.map(players, fn p ->
        total = ScoreSheet.total(valid_scores(scores[p.id], invalid_cells, p.id))
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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div id="game-session" phx-hook="GameSession" class="space-y-4">
        <div class="flex items-center justify-between gap-2 flex-wrap">
          <h1 class="text-3xl font-bold">AltistYatzy 🎲</h1>
          <div class="flex gap-2">
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
          <div>
            <strong>{@game.name}</strong>
            <span class="text-sm opacity-70">· {@game.played_on}</span>
            <p :if={@game.comment && @game.comment != ""} class="text-sm">{@game.comment}</p>
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
                    <.score_input player={p} category={key} scores={@scores} invalid_cells={@invalid_cells} disabled={is_nil(@game)} />
                  </td>
                </tr>

                <tr class="bg-base-200 font-semibold">
                  <th class="text-right">Välisumma</th>
                  <td :for={p <- @players} class="text-center">
                    {ScoreSheet.upper_subtotal(valid_scores(@scores[p.id], @invalid_cells, p.id))}
                  </td>
                </tr>

                <tr class="bg-base-200 font-semibold">
                  <th class="text-right">Bonus</th>
                  <td :for={p <- @players} class="text-center">
                    {ScoreSheet.bonus(valid_scores(@scores[p.id], @invalid_cells, p.id))}
                  </td>
                </tr>

                <tr :for={{key, label} <- ScoreSheet.lower_categories()}>
                  <th class="text-right font-medium">{label}</th>
                  <td :for={p <- @players} class="p-1">
                    <.score_input player={p} category={key} scores={@scores} invalid_cells={@invalid_cells} disabled={is_nil(@game)} />
                  </td>
                </tr>

                <tr class="bg-base-200 font-bold text-lg">
                  <th class="text-right">Summa</th>
                  <td :for={p <- @players} class="text-center">
                    {ScoreSheet.total(valid_scores(@scores[p.id], @invalid_cells, p.id))}
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
