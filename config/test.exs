use Mix.Config

config :expected,
  store: :memory,
  process_name: :test_store,
  auth_cookie: "_test_auth",
  session_store: :ets,
  session_opts: [table: :test_session],
  session_cookie: "_test_key"

# Print only warnings and errors during test
config :logger, level: :warn
