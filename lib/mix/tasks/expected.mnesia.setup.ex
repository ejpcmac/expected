defmodule Mix.Tasks.Expected.Mnesia.Setup do
  use Mix.Task

  @shortdoc "Creates the Mnesia table for :expected"

  @moduledoc """
  Creates the Mnesia table for `:expected`.

  To set up the Mnesia table for login storage, configure it in your
  `config.exs`:

      config :expected,
        store: :mnesia,
        table: :logins,
        ...

  Then, simply run this mix task:

      mix expected.mnesia.setup

  If you use to start your IEx development sessions with a node name, you must
  also run `expected.mnesia.setup` with the same node name to effictively create
  the Mnesia table on the good node:

      elixir --sname "my_node@my_host" -S mix expected.mnesia.setup

  ## Configuration

  By default, the Mnesia files will be stored in `Mnesia.nonode@nohost` in your
  project directory. You can add this directory to your `.gitignore`. If you
  want to store them elsewhere, you can configure Mnesia in your `config.exs`:

      config :mnesia,
        dir: 'path/to/dir'  # Note the simple quotes, Erlang strings are charlists ;-)

  For more information about Mnesia and its configuration, please see `:mnesia`
  in the Erlang documentation.
  """

  alias Expected.MnesiaStore.Helpers
  alias Expected.ConfigurationError
  alias Expected.MnesiaTableExistsError

  @spec run(OptionParser.argv()) :: boolean()
  def run(_argv) do
    Helpers.setup!()
    table = Application.fetch_env!(:expected, :table)

    Mix.shell().info(
      IO.ANSI.green() <>
        "The Mnesia table '#{table}' has been successfully set up for login " <>
        "storage!"
    )
  rescue
    e in ConfigurationError ->
      Mix.shell().error(ConfigurationError.message(e))

    e in MnesiaTableExistsError ->
      Mix.shell().error(MnesiaTableExistsError.message(e))
  end
end
