defmodule YatzyWeb.GamesLive do
  use YatzyWeb, :live_view

  import YatzyWeb.GameHelpers

  alias Yatzy.{Chat, Games, Locale}
  alias Yatzy.Games.Game

  @impl true
  def mount(_params, _session, socket) do
    enabled_types = MapSet.new(Game.game_types())
    current_user = socket.assigns[:current_user]
    page_size = 20

    if connected?(socket) and current_user do
      Chat.subscribe_recent()
    end

    recent =
      if current_user, do: Chat.list_recent_messages(limit: page_size), else: []

    {:ok,
     socket
     |> assign(:page_title, "Pelit")
     |> assign(:enabled_types, enabled_types)
     |> assign(:games, Games.list_games(enabled_types))
     |> assign(:lobby_body, "")
     |> assign(:lobby_error, nil)
     |> assign(:page_size, page_size)
     |> assign(:oldest_loaded_id, oldest_id(recent))
     |> assign(:can_load_more, length(recent) >= page_size)
     |> stream(:recent_chat, recent)}
  end

  defp oldest_id([]), do: nil
  defp oldest_id(msgs), do: List.last(msgs).id

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

  def handle_event("change_lobby", %{"body" => body}, socket) do
    {:noreply, assign(socket, :lobby_body, body)}
  end

  def handle_event("send_lobby", %{"body" => body}, socket) do
    user = socket.assigns.current_user
    body = body |> to_string() |> String.trim()

    cond do
      is_nil(user) ->
        {:noreply, socket}

      body == "" ->
        {:noreply, assign(socket, :lobby_body, "")}

      true ->
        case Chat.create_message(:global, user, body) do
          {:ok, _msg} ->
            {:noreply, socket |> assign(:lobby_body, "") |> assign(:lobby_error, nil)}

          {:error, _changeset} ->
            {:noreply, assign(socket, :lobby_error, "Viestin lähetys epäonnistui.")}
        end
    end
  end

  def handle_event("load_more", _params, socket) do
    before_id = socket.assigns.oldest_loaded_id
    page_size = socket.assigns.page_size

    msgs = Chat.list_recent_messages(limit: page_size, before_id: before_id)

    socket =
      Enum.reduce(msgs, socket, fn m, acc ->
        stream_insert(acc, :recent_chat, m, at: -1)
      end)

    {:noreply,
     socket
     |> assign(:oldest_loaded_id, oldest_id(msgs) || before_id)
     |> assign(:can_load_more, length(msgs) >= page_size)}
  end

  @impl true
  def handle_info({:chat_message, msg}, socket) do
    {:noreply, stream_insert(socket, :recent_chat, msg, at: 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="flex flex-col lg:flex-row lg:items-start gap-6">
        <aside
          :if={@current_user}
          class="w-full lg:w-72 shrink-0 rounded-box border border-base-300 p-3 bg-base-100 flex flex-col gap-2"
        >
          <h2 class="font-semibold">Viimeisimmät keskustelut</h2>

          <p :if={@lobby_error} class="text-xs text-error">{@lobby_error}</p>

          <form phx-submit="send_lobby" phx-change="change_lobby" class="flex flex-col gap-2">
            <textarea
              id="lobby-input"
              phx-hook="ChatEnter"
              name="body"
              rows="2"
              maxlength="2000"
              placeholder="Kirjoita viesti… (Enter lähettää, Shift+Enter rivinvaihto)"
              class="textarea textarea-bordered textarea-sm w-full"
            >{@lobby_body}</textarea>
            <div class="flex justify-between items-center gap-2">
              <details class="dropdown">
                <summary class="btn btn-sm btn-ghost" title="Lisää emoji">😀</summary>
                <div
                  id="lobby-emojis"
                  phx-hook="EmojiPicker"
                  data-target="#lobby-input"
                  class="dropdown-content menu menu-xs p-2 mt-1 shadow bg-base-100 rounded-box w-60 z-10 flex flex-row flex-wrap gap-0 max-h-56 overflow-y-auto"
                >
                  <button
                    :for={e <- emojis()}
                    type="button"
                    data-emoji={e}
                    class="btn btn-ghost btn-sm px-1.5 text-lg"
                  >
                    {e}
                  </button>
                </div>
              </details>
              <button
                type="submit"
                class="btn btn-sm btn-primary"
                disabled={String.trim(@lobby_body) == ""}
              >
                Lähetä
              </button>
            </div>
          </form>

          <div
            id="recent-chat"
            phx-update="stream"
            class="overflow-y-auto max-h-[60vh] space-y-2 pr-1 empty:before:content-['Ei_vielä_viestejä.'] empty:before:text-sm empty:before:text-base-content/70"
          >
            <div :for={{dom_id, msg} <- @streams.recent_chat} id={dom_id} class="text-sm">
              <div class="flex items-center gap-2 flex-wrap">
                <.link
                  :if={msg.game}
                  navigate={game_link(msg.game)}
                  class="badge badge-outline badge-sm"
                >
                  {msg.game.name}
                </.link>
                <span class="font-medium">{username(msg)}</span>
                <span class="text-xs opacity-60">
                  {Locale.format_datetime(msg.inserted_at)}
                </span>
              </div>
              <div class="whitespace-pre-wrap break-words">{msg.body}</div>
            </div>
          </div>

          <button
            :if={@can_load_more}
            type="button"
            phx-click="load_more"
            class="btn btn-sm btn-ghost"
          >
            Näytä lisää
          </button>
        </aside>

        <div class="flex-1 max-w-3xl space-y-4">
          <div class="flex items-center justify-between gap-2 flex-wrap">
            <h1 class="text-3xl font-bold">AltistYatzy 🎲</h1>
            <.link
              :if={@current_user}
              href={~p"/play"}
              class="btn btn-sm btn-primary"
            >
              + Aloita uusi peli
            </.link>
          </div>

          <.game_type_filter enabled_types={@enabled_types} />

          <p :if={@games == []} class="text-base-content/70">
            Ei pelejä valituilla pelityypeillä.
          </p>

          <ul
            :if={@games != []}
            class="divide-y divide-base-300 rounded-box border border-base-300"
          >
            <li :for={g <- @games}>
              <.link
                navigate={game_link(g)}
                class="block p-4 hover:bg-base-200 flex items-center justify-between gap-3"
              >
                <div class="min-w-0">
                  <div class="flex items-center gap-2 flex-wrap">
                    <span class="font-semibold truncate">{g.name}</span>
                    <span class={status_badge_class(g.status)}>{Game.status_label(g.status)}</span>
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
      </div>
    </Layouts.app>
    """
  end

  defp game_link(%Game{status: :active, id: id}), do: ~p"/play/#{id}"
  defp game_link(%Game{id: id}), do: ~p"/games/#{id}"

  defp username(%{user: %{username: u}}) when is_binary(u), do: u
  defp username(_), do: "(poistettu)"

  @emojis ~w(
    🎲 🎯 🏆 🥇 🥈 🥉 🎉 🥳 🎊 ✨
    👍 👎 👏 🙌 💪 🤝 🤞 🤘 ✊ 🤙
    😀 😂 🤣 😅 😆 😉 😊 😎 🤩 🥲
    🤔 🙃 😴 😭 😱 😡 🤯 🥵 🥶 🤠
    ❤️ 🧡 💛 💚 💙 💜 🖤 🤍 💯 🔥
    ☕ 🍻 🍷 🍕 🍔 🍿 🧀 🍩 🍫 🍰 🎂 🥂
  )

  defp emojis, do: @emojis
end
