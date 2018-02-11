defmodule Expected.MnesiaStoreTest do
  use Expected.MnesiaCase
  use Expected.Store.Test, store: Expected.MnesiaStore

  alias Expected.MnesiaStoreError

  # Must be defined for Expected.Store.Test to work.
  defp init_store(_) do
    create_table()
    %{opts: init(table: @table)}
  end

  # Must be defined for Expected.Store.Test to work.
  defp clear_store(table), do: :mnesia.clear_table(table)

  describe "init/1" do
    property "returns the table name fetched from options" do
      check all table <- atom(:alphanumeric) do
        assert init(table: table) == table
      end
    end

    test "raises an exception if there is no table in the options" do
      assert_raise ConfigurationError,
                   ConfigurationError.message(%{reason: :no_mnesia_table}),
                   fn -> init([]) end
    end
  end

  describe "if the Mnesia table does not exist, an exception is raised" do
    property "by list_user_logins/2" do
      check all username <- username(),
                table <- atom(:alphanumeric) do
        assert_raise MnesiaStoreError,
                     MnesiaStoreError.message(%{reason: :table_not_exists}),
                     fn -> list_user_logins(username, table) end
      end
    end

    test "by get/3" do
      check all %{username: username, serial: serial} <- gen_login(),
                table <- atom(:alphanumeric) do
        assert_raise MnesiaStoreError,
                     MnesiaStoreError.message(%{reason: :table_not_exists}),
                     fn -> get(username, serial, table) end
      end
    end

    test "by put/2" do
      check all login <- gen_login(),
                table <- atom(:alphanumeric) do
        assert_raise MnesiaStoreError,
                     MnesiaStoreError.message(%{reason: :table_not_exists}),
                     fn -> put(login, table) end
      end
    end

    test "by delete/3" do
      check all %{username: username, serial: serial} <- gen_login(),
                table <- atom(:alphanumeric) do
        assert_raise MnesiaStoreError,
                     MnesiaStoreError.message(%{reason: :table_not_exists}),
                     fn -> delete(username, serial, table) end
      end
    end
  end

  describe "if the Mnesia table has a bad format, an exception is raised" do
    property "by put/2" do
      check all login <- gen_login(),
                table <- atom(:alphanumeric),
                attributes <- uniq_list_of(atom(:alphanumeric), length: 3) do
        :mnesia.create_table(table, attributes: attributes)

        assert_raise MnesiaStoreError,
                     MnesiaStoreError.message(%{reason: :invalid_table_format}),
                     fn -> put(login, table) end
      end
    end
  end
end
