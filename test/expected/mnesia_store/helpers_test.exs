defmodule Expected.MnesiaStore.HelpersTest do
  use Expected.MnesiaCase

  alias Expected.MnesiaStore.Helpers

  describe "setup!/0" do
    test "creates a Mnesia schema and table according to the configuration" do
      assert :ok = Helpers.setup!()
      assert {:aborted, {:already_exists, _}} = :mnesia.create_table(@table, [])
      assert :mnesia.table_info(@table, :attributes) == @attributes
    end

    test "raises if the table name is not provided in the configuration" do
      Application.delete_env(:expected, :table)

      assert_raise ConfigurationError,
                   ConfigurationError.message(%{reason: :no_mnesia_table}),
                   fn -> Helpers.setup!() end
    end

    test "raises if a different table already exists with the same name" do
      :mnesia.create_table(@table, attributes: [:id, :data])

      assert_raise MnesiaTableExistsError, fn ->
        Helpers.setup!()
      end
    end

    test "does nothing if the table already exists" do
      :mnesia.create_table(@table, attributes: @attributes)
      assert :ok = Helpers.setup!()
    end
  end

  describe "setup/3" do
    test "creates a Mnesia schema and table and returns :ok if it’s all good" do
      assert :ok = Helpers.setup(@table)
      assert {:aborted, {:already_exists, _}} = :mnesia.create_table(@table, [])
      assert :mnesia.table_info(@table, :attributes) == @attributes
    end

    test "can create a persistent table" do
      filename = Atom.to_string(@table) <> ".DCD"

      assert :ok = Helpers.setup(@table, :persistent)
      assert "Mnesia.nonode@nohost" |> Path.join(filename) |> File.exists?()
    end

    test "can create a volatile table" do
      assert :ok = Helpers.setup(@table, :volatile)
      refute "Mnesia.nonode@nohost" |> Path.join("test.DCD") |> File.exists?()
    end

    test "works if a persistent schema already exists" do
      {:atomic, :ok} =
        :mnesia.change_table_copy_type(:schema, node(), :disc_copies)

      assert :ok = Helpers.setup(@table)
    end

    test "returns an error if the schema cannot be written on disk" do
      File.touch("Mnesia.nonode@nohost")
      assert {:aborted, _} = Helpers.setup(@table)
    end

    test "returns {:error | :aborted, reason} if an error occured" do
      :mnesia.create_table(@table, [])
      assert {:error, _} = Helpers.setup(@table)
    end
  end
end
