defmodule Expected.MemoryStoreTest do
  use ExUnit.Case
  use Expected.Store.Test, store: Expected.MemoryStore

  alias Expected.ConfigurationError

  @server :store_test

  # Must be defined for Expected.Store.Test to work.
  defp init_store(_) do
    Application.put_env(:expected, :process_name, @server)
    start_link(@logins)
    %{opts: init(process_name: @server)}
  end

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
    test "returns the server name fetched from options" do
      assert init(process_name: @server) == @server
    end

    test "raises an exception if there is no process_name in the options" do
      assert_raise ConfigurationError,
                   ConfigurationError.message(%{reason: :no_process_name}),
                   fn -> init([]) end
    end
  end
end
