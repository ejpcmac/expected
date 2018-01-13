Mix.shell(Mix.Shell.Process)

defmodule Mix.Tasks.Expected.Mnesia.ClearTest do
  use Expected.MnesiaCase

  import Mix.Tasks.Expected.Mnesia.Clear

  describe "run/1" do
    test "clears all logins from the store accorting to the configuration" do
      :mnesia.create_table(@table, attributes: [:key, :value])

      record = {@table, :test, :test}
      :mnesia.dirty_write(record)

      assert :mnesia.dirty_match_object({@table, :_, :_}) == [record]
      run([])
      assert :mnesia.dirty_match_object({@table, :_, :_}) == []
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
