defmodule Mix.Tasks.Expected.Mnesia.Drop do
  use Mix.Task

  @shortdoc "Drops the Expected Mnesia table"

  @moduledoc """
  Drops the Expected Mnesia table.

  To drop the Expected Mnesia table, run this mix task:

      $ mix expected.mnesia.drop

  If you use to start your IEx development sessions with a node name, you must
  also run `expected.mnesia.drop` with the same node name to effictively run the
  command on the good Mnesia database:

      $ elixir --sname "my_node@my_host" -S mix expected.mnesia.drop
  """

  alias Expected.MnesiaStore.Helpers
  alias Expected.ConfigurationError

  @spec run(OptionParser.argv()) :: boolean()
  def run(_argv) do
    Helpers.drop!()
  rescue
    e in ConfigurationError -> Mix.shell().error(ConfigurationError.message(e))
  end
end
