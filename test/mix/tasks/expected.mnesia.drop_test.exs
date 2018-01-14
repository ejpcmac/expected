Mix.shell(Mix.Shell.Process)

defmodule Mix.Tasks.Expected.Mnesia.DropTest do
  use Expected.MnesiaCase

  import Mix.Tasks.Expected.Mnesia.Drop

  describe "run/1" do
    test "drops the Mnesia table accorting to the configuration" do
      :mnesia.create_table(@table, attributes: @attributes)
      run([])

      assert {:aborted, {:no_exists, @table}} = :mnesia.delete_table(@table)
    end

    test "prints an error message if the table name is not provided in the
          configuration" do
      Application.delete_env(:expected, :table)
      run([])

      assert_received {:mix_shell, :error, [msg]}
      assert msg =~ ConfigurationError.message(%{reason: :no_mnesia_table})
    end
  end
end
