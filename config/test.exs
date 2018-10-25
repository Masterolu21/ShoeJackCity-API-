use Mix.Config

# Timeout of Game processes
config :sjc,
  game_timeout: 800,
  round_timeout: 500,
  env: :test

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :sjc, SjcWeb.Endpoint,
  http: [port: 4001],
  server: false

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
