use Mix.Config

config :expected,
  store: :mnesia,
  table: :logins,
  auth_cookie: "_expected_auth",
  session_store: :ets,
  session_opts: [table: :session],
  session_cookie: "_expected_key"

# Clear the console before each test run
config :mix_test_watch, clear: true
