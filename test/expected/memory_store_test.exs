defmodule Expected.MemoryStoreTest do
  use ExUnit.Case
  use Expected.Store.Test, store: Expected.MemoryStore

  alias Expected.ConfigurationError

  @server :store_test

  # Must be defined for Expected.Store.Test to work.
  defp init_store(_) do
    Application.put_env(:expected, :process_name, @server)
    start_link()
    %{opts: init(process_name: @server)}
  end

  # Must be defined for Expected.Store.Test to work.
  defp clear_store(server), do: clear(server)

  describe "start_link/0" do
    test "raises an exception if there is no process_name in the application
          environment" do
      Application.delete_env(:expected, :process_name)

      assert_raise ConfigurationError,
                   ConfigurationError.message(%{reason: :no_process_name}),
                   fn -> start_link() end
    end
  end

  describe "init/1" do
    property "returns the server name fetched from options" do
      check all process_name <- atom(:alphanumeric) do
        assert init(process_name: process_name) == process_name
      end
    end

    test "raises an exception if there is no process_name in the options" do
      assert_raise ConfigurationError,
                   ConfigurationError.message(%{reason: :no_process_name}),
                   fn -> init([]) end
    end
  end

  describe "clear/1" do
    setup [:init_store]

    property "clears all logins from the memory store" do
      check all logins <- uniq_list_of(gen_login(), length: 5) do
        clear_store_and_put_logins(logins, @server)

        Enum.each(logins, fn login ->
          assert get(login.username, login.serial, @server) == {:ok, login}
        end)

        assert clear(@server) == :ok

        Enum.each(logins, fn login ->
          assert get(login.username, login.serial, @server) ==
                   {:error, :no_login}
        end)
      end
    end
  end
end
