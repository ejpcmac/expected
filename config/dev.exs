use Mix.Config

config :expected,
  store: :mnesia,
  table: :logins

# Clear the console before each test run
config :mix_test_watch, clear: true
