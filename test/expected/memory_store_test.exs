defmodule Expected.MemoryStoreTest do
  use ExUnit.Case, async: true
  use Expected.Store.Test, store: Expected.MemoryStore

  # Must be defined for Expected.Store.Test to work.
  defp init_store(_) do
    %{opts: init(default: @logins)}
  end

  describe "init/0" do
    test "returns a server’s PID" do
      assert is_pid(init([]))
    end
  end
end
