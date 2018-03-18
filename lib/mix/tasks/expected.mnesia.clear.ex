defmodule Mix.Tasks.Expected.Mnesia.Clear do
  use Mix.Task

  @shortdoc "Clears all logins from the Mnesia table"

  @moduledoc """
  Clears all logins from the Mnesia table.

  To clear all logins from the Expected Mnesia table, run this mix task:

      $ mix expected.mnesia.clear

  If you use to start your IEx development sessions with a node name, you must
  also run `expected.mnesia.clear` with the same node name to effictively run
  the command on the good Mnesia database:

      $ elixir --sname "my_node@my_host" -S mix expected.mnesia.clear
  """

  alias Expected.MnesiaStore.Helpers
  alias Expected.ConfigurationError

  @dialyzer :no_undefined_callbacks

  @spec run(OptionParser.argv()) :: boolean()
  def run(_argv) do
    Helpers.clear!()
  rescue
    e in ConfigurationError -> Mix.shell().error(ConfigurationError.message(e))
  end
end
