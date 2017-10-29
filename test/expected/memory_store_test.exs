defmodule Expected.MemoryStoreTest do
  use ExUnit.Case, async: true
  use Expected.Store.Test, store: Expected.MemoryStore

  @server :store_test

  # Must be defined for Expected.Store.Test to work.
  defp init_store(_) do
    Application.put_env(:expected, :process_name, @server)
    start_link(@logins)
    %{opts: init(process_name: @server)}
  end

  describe "init/0" do
    test "returns the server name fetched from options" do
      assert init(process_name: @server) == @server
    end
  end
end
