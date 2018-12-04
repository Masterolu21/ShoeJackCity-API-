use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :sjc, SjcWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

config :sjc,
  game_intervals: [days: 10],
  round_timeout: 2_000

config :sjc, SjcWeb.Guardian,
  secret_key: "QPpZ60CkjQfcXoBkFsgz1pmbi2fBQXs/cGDsp46Mqd1wnA8fOAXQSsftMxQsi9nl"

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Configure your database
config :sjc, Sjc.Repo,
  username: "postgres",
  password: "postgres",
  database: "sjc_dev",
  hostname: "localhost",
  pool_size: 10
