defmodule Expected.MnesiaStoreTest do
  use ExUnit.Case, async: true
  use Expected.Store.Test, store: Expected.MnesiaStore

  alias Expected.ConfigurationError
  alias Expected.MnesiaStoreError

  @table :logins_test

  # Must be defined for Expected.Store.Test to work.
  defp init_store(_) do
    :mnesia.start()
    :mnesia.create_table(@table, attributes: [:username, :logins])

    user_logins = %{@login1.serial => @login1}
    :mnesia.dirty_write({@table, @login1.username, user_logins})

    on_exit fn -> :mnesia.stop() end

    %{opts: init(table: @table)}
  end

  defp start_mnesia(_) do
    :mnesia.start()
    on_exit fn -> :mnesia.stop() end
  end

  defp bad_table(_) do
    :mnesia.create_table(@table, attributes: [:username, :logins, :other])
    :ok
  end

  describe "init/1" do
    test "returns the table name fetched from options" do
      assert init(table: @table) == @table
    end

    test "raises an exception if there is no table in the options" do
      assert_raise ConfigurationError,
                   ConfigurationError.message(%{reason: :no_mnesia_table}),
                   fn -> init([]) end
    end
  end

  describe "if the Mnesia table does not exist, an exception is raised" do
    setup [:start_mnesia]

    test "by list_user_logins/2" do
      assert_raise MnesiaStoreError,
                   MnesiaStoreError.message(%{reason: :table_not_exists}),
                   fn -> list_user_logins("user", :a_table) end
    end

    test "by get/3" do
      assert_raise MnesiaStoreError,
                   MnesiaStoreError.message(%{reason: :table_not_exists}),
                   fn -> get("user", "serial", :a_table) end
    end

    test "by put/2" do
      assert_raise MnesiaStoreError,
                   MnesiaStoreError.message(%{reason: :table_not_exists}),
                   fn -> put(@login1, :a_table) end
    end

    test "by delete/3" do
      assert_raise MnesiaStoreError,
                   MnesiaStoreError.message(%{reason: :table_not_exists}),
                   fn -> delete("user", "serial", :a_table) end
    end
  end

  describe "if the Mnesia table has a bad format, an exception is raised" do
    setup [:start_mnesia, :bad_table]

    test "by put/2" do
      assert_raise MnesiaStoreError,
                   MnesiaStoreError.message(%{reason: :invalid_table_format}),
                   fn -> put(@login1, @table) end
    end
  end
end
