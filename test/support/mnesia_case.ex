defmodule Expected.MnesiaCase do
  @moduledoc """
  A test case for testing Mnesia helpers.
  """

  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case

      alias Expected.ConfigurationError
      alias Expected.MnesiaTableExistsError

      @table :logins_test
      @attributes [:username, :logins]

      setup do
        Application.put_env(:expected, :table, @table)
        File.rm_rf("Mnesia.nonode@nohost")
        :mnesia.start()

        on_exit fn ->
          :mnesia.stop()
          :ok = :mnesia.delete_schema([node()])
          File.rm_rf("Mnesia.nonode@nohost")
          Application.delete_env(:expected, :table)
        end
      end
    end
  end
end
