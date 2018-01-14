Mix.shell(Mix.Shell.Process)

defmodule Mix.Tasks.Expected.Mnesia.SetupTest do
  use Expected.MnesiaCase

  import Mix.Tasks.Expected.Mnesia.Setup

  describe "run/1" do
    test "creates a Mnesia schema and table according to the configuration" do
      run([])

      assert_received {:mix_shell, :info, [msg]}
      assert msg =~ "has been successfully set up for login storage!"
      assert {:aborted, {:already_exists, _}} = :mnesia.create_table(@table, [])
    end

    test "prints an error message if the table name is not provided in the
          configuration" do
      Application.delete_env(:expected, :table)
      run([])

      assert_received {:mix_shell, :error, [msg]}
      assert msg =~ ConfigurationError.message(%{reason: :no_mnesia_table})
    end

    test "prints an error message if a different table already exists with the
          same name" do
      :mnesia.create_table(@table, attributes: [:id, :data])
      run([])

      assert_received {:mix_shell, :error, [msg]}
      assert msg =~ MnesiaTableExistsError.message(%{table: @table})
    end
  end
end
