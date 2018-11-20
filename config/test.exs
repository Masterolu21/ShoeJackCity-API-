use Mix.Config

# Timeout of Game processes
config :sjc,
  game_timeout: 800,
  round_timeout: 500,
  env: :test,
  game_intervals: [seconds: 1]

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :sjc, SjcWeb.Endpoint,
  http: [port: 4001],
  server: false

config :argon2_elixir,
  t_cost: 1,
  m_cost: 8

config :sjc, SjcWeb.Guardian,
  secret_key: "02N47b8V/ygx1EVpP4C8L08F0SJ/Ri3D8K8s0HXGkgtLQGJGER74fW+9/oQXwM90"

# Print only warnings and errors during test
config :logger, level: :debug

# Configure your database
config :sjc, Sjc.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "sjc_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :tesla, adapter: Tesla.Mock
