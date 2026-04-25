defmodule YatzyWeb.ChatComponent do
  use YatzyWeb, :live_component

  alias Yatzy.{Chat, Locale}

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:subscribed?, false)
     |> assign(:body, "")
     |> assign(:error, nil)
     |> stream(:messages, [])}
  end

  @impl true
  def update(%{action: {:chat_message, msg}}, socket) do
    {:ok, stream_insert(socket, :messages, msg)}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> ensure_subscribed_and_loaded()

    {:ok, socket}
  end

  defp ensure_subscribed_and_loaded(socket) do
    cond do
      is_nil(socket.assigns.current_user) ->
        socket

      socket.assigns.subscribed? ->
        socket

      true ->
        Chat.subscribe(socket.assigns.scope)
        messages = Chat.list_messages(socket.assigns.scope)

        socket
        |> stream(:messages, messages, reset: true)
        |> assign(:subscribed?, true)
    end
  end

  @impl true
  def handle_event("send", %{"body" => body}, socket) do
    user = socket.assigns.current_user
    body = body |> to_string() |> String.trim()

    cond do
      is_nil(user) ->
        {:noreply, socket}

      body == "" ->
        {:noreply, assign(socket, :body, "")}

      true ->
        case Chat.create_message(socket.assigns.scope, user, body) do
          {:ok, _msg} ->
            {:noreply, socket |> assign(:body, "") |> assign(:error, nil)}

          {:error, changeset} ->
            {:noreply, assign(socket, :error, format_error(changeset))}
        end
    end
  end

  def handle_event("change", %{"body" => body}, socket) do
    {:noreply, assign(socket, :body, body)}
  end

  defp format_error(%Ecto.Changeset{} = cs) do
    case Keyword.get(cs.errors, :body) do
      {msg, _} -> "Viesti: #{msg}"
      _ -> "Viestin lähetys epäonnistui."
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <aside
      id={@id}
      class="w-full lg:w-72 shrink-0 rounded-box border border-base-300 p-3 flex flex-col gap-2 bg-base-100"
    >
      <div class="flex items-center justify-between">
        <h2 class="font-semibold">Keskustelu</h2>
      </div>

      <div
        id={"#{@id}-messages"}
        phx-hook="ChatScroll"
        phx-update="stream"
        class="flex-1 overflow-y-auto max-h-[60vh] min-h-[12rem] space-y-2 pr-1"
      >
        <div
          :for={{dom_id, msg} <- @streams.messages}
          id={dom_id}
          class="text-sm"
        >
          <div class="flex items-baseline gap-2">
            <span class="font-medium truncate">{username(msg)}</span>
            <span class="text-xs opacity-60">{Locale.format_datetime(msg.inserted_at)}</span>
          </div>
          <div class="whitespace-pre-wrap break-words">{msg.body}</div>
        </div>
      </div>

      <p :if={@error} class="text-xs text-error">{@error}</p>

      <form
        phx-submit="send"
        phx-change="change"
        phx-target={@myself}
        class="flex flex-col gap-2"
      >
        <textarea
          id={"#{@id}-input"}
          phx-hook="ChatEnter"
          name="body"
          rows="2"
          maxlength="2000"
          placeholder="Kirjoita viesti… (Enter lähettää, Shift+Enter rivinvaihto)"
          class="textarea textarea-bordered textarea-sm w-full"
        >{@body}</textarea>
        <div class="flex justify-between items-center gap-2">
          <details class="dropdown dropdown-top">
            <summary class="btn btn-sm btn-ghost" title="Lisää emoji">😀</summary>
            <div
              id={"#{@id}-emojis"}
              phx-hook="EmojiPicker"
              data-target={"##{@id}-input"}
              class="dropdown-content menu menu-xs p-2 mb-1 shadow bg-base-100 rounded-box w-60 z-10 flex flex-row flex-wrap gap-0 max-h-56 overflow-y-auto"
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
            disabled={String.trim(@body) == ""}
          >
            Lähetä
          </button>
        </div>
      </form>
    </aside>
    """
  end

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
