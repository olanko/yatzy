defmodule Yatzy.Repo do
  use Ecto.Repo,
    otp_app: :yatzy,
    adapter: Ecto.Adapters.SQLite3
end
