import Config

config :yatzy, Yatzy.Repo,
  database: Path.expand("../yatzy_test.db", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5

# Speed up tests — argon2 is intentionally slow.
config :argon2_elixir, t_cost: 1, m_cost: 8

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :yatzy, YatzyWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "frZSVbTdcfQT9Wh6YZn7m6rRtW5BEG+gg+aSOxa8KJyDpHX+SN8+dhvyL+1iKC/T",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
