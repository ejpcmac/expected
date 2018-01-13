defmodule Expected.MnesiaCase do
  @moduledoc """
  A test case for testing Mnesia helpers.
  """

  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case

      import Expected.MnesiaStore.LoginRecord

      alias Expected.Login
      alias Expected.ConfigurationError
      alias Expected.MnesiaTableExistsError

      @table :logins_test
      @attributes Login.keys()

      setup do
        Application.put_env(:expected, :table, @table)
        File.rm_rf("Mnesia.nonode@nohost")
        :mnesia.start()

        on_exit(fn ->
          :mnesia.stop()
          :ok = :mnesia.delete_schema([node()])
          File.rm_rf("Mnesia.nonode@nohost")
          Application.delete_env(:expected, :table)
        end)
      end

      defp create_table do
        :mnesia.create_table(
          @table,
          type: :bag,
          record_name: :login,
          attributes: @attributes,
          index: [:serial, :last_login]
        )
      end
    end
  end
end
