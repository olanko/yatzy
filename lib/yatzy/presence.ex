defmodule Yatzy.Presence do
  @moduledoc """
  Tracks which users currently have a connected LiveView. Used to show
  "online" indicators on the user list.

  Keys are stringified user ids; metas carry `%{username: ...}`.
  """

  use Phoenix.Presence,
    otp_app: :yatzy,
    pubsub_server: Yatzy.PubSub

  @topic "users:online"

  def topic, do: @topic
end
