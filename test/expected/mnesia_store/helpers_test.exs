defmodule Expected.MnesiaStore.HelpersTest do
  use Expected.MnesiaCase

  alias Expected.MnesiaStore.Helpers

  describe "setup!/0" do
    test "creates a Mnesia schema and table according to the configuration" do
      assert Helpers.setup!() == :ok
      assert {:aborted, {:already_exists, _}} = :mnesia.create_table(@table, [])
      assert :mnesia.table_info(@table, :type) == :bag
      assert (1 + login(:serial)) in :mnesia.table_info(@table, :index)
      assert (1 + login(:last_login)) in :mnesia.table_info(@table, :index)
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
      assert Helpers.setup!() == :ok
    end
  end

  describe "clear!/0" do
    test "clears all logins from the store accorting to the configuration" do
      :mnesia.create_table(@table, attributes: [:key, :value])

      record = {@table, :test, :test}
      :mnesia.dirty_write(record)

      assert :mnesia.dirty_match_object({@table, :_, :_}) == [record]
      assert Helpers.clear!() == :ok
      assert :mnesia.dirty_match_object({@table, :_, :_}) == []
    end

    test "raises if the table name is not provided in the configuration" do
      Application.delete_env(:expected, :table)

      assert_raise ConfigurationError,
                   ConfigurationError.message(%{reason: :no_mnesia_table}),
                   fn -> Helpers.clear!() end
    end
  end

  describe "drop!/0" do
    test "drops the given Mnesia table" do
      :mnesia.create_table(@table, attributes: @attributes)

      assert Helpers.drop!() == :ok
      assert :mnesia.delete_table(@table) == {:aborted, {:no_exists, @table}}
    end

    test "raises if the table name is not provided in the configuration" do
      Application.delete_env(:expected, :table)

      assert_raise ConfigurationError,
                   ConfigurationError.message(%{reason: :no_mnesia_table}),
                   fn -> Helpers.drop!() end
    end
  end

  describe "setup/2" do
    test "creates a Mnesia schema and table and returns :ok if it’s all good" do
      assert Helpers.setup(@table) == :ok
      assert {:aborted, {:already_exists, _}} = :mnesia.create_table(@table, [])
      assert :mnesia.table_info(@table, :attributes) == @attributes
    end

    test "can create a persistent table" do
      filename = Atom.to_string(@table) <> ".DCD"

      assert Helpers.setup(@table, :persistent) == :ok
      assert "Mnesia.nonode@nohost" |> Path.join(filename) |> File.exists?()
    end

    test "can create a volatile table" do
      assert Helpers.setup(@table, :volatile) == :ok
      refute "Mnesia.nonode@nohost" |> Path.join("test.DCD") |> File.exists?()
    end

    test "works if a persistent schema already exists" do
      {:atomic, :ok} =
        :mnesia.change_table_copy_type(:schema, node(), :disc_copies)

      assert Helpers.setup(@table) == :ok
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

  describe "clear/1" do
    test "clears all logins from the given table" do
      :mnesia.create_table(@table, attributes: [:key, :value])

      record = {@table, :test, :test}
      :mnesia.dirty_write(record)

      assert :mnesia.dirty_match_object({@table, :_, :_}) == [record]
      assert Helpers.clear(@table) == :ok
      assert :mnesia.dirty_match_object({@table, :_, :_}) == []
    end

    test "works as well if the table does not exist" do
      assert Helpers.clear(@table) == :ok
    end
  end

  describe "drop/1" do
    test "drops the given Mnesia table" do
      :mnesia.create_table(@table, attributes: @attributes)

      assert Helpers.drop(@table) == :ok
      assert :mnesia.delete_table(@table) == {:aborted, {:no_exists, @table}}
    end

    test "works as well if the given table does not exist" do
      assert Helpers.drop(@table) == :ok
    end
  end
end
