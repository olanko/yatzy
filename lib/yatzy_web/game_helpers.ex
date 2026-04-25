defmodule YatzyWeb.GameHelpers do
  @moduledoc "Shared rendering helpers for game-related views."

  def status_badge_class(:active), do: "badge badge-success badge-sm"
  def status_badge_class(:ended), do: "badge badge-neutral badge-sm"
  def status_badge_class(:cancelled), do: "badge badge-error badge-sm"
  def status_badge_class(_), do: "badge badge-ghost badge-sm"
end
