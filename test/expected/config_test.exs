defmodule Expected.ConfigTest do
  use ExUnit.Case
  use Plug.Test

  alias Expected.Config

  setup do
    Application.put_env(:expected, :store, :memory)
    Application.put_env(:expected, :process_name, :test_store)

    on_exit fn ->
      Application.delete_env(:expected, :store)
      Application.delete_env(:expected, :process_name)
    end
  end

  describe "init/1" do
    test "gets the store module from the application environment" do
      assert %{store: Expected.MemoryStore} = Config.init([])
    end

    test "converts the :memory store to Expected.MemoryStore" do
      Application.put_env(:expected, :store, :memory)
      assert %{store: Expected.MemoryStore} = Config.init([])
    end

    test "keeps unknown store as is" do
      Application.put_env(:expected, :store, Expected.MemoryStore)
      assert %{store: Expected.MemoryStore} = Config.init([])
    end

    test "gets the store configuration from the application environment" do
      assert %{store_opts: :test_store} = Config.init([])
    end

    test "raises an exception if the store is not configured" do
      Application.delete_env(:expected, :store)

      assert_raise Expected.ConfigurationError,
        Expected.ConfigurationError.message(%{reason: :no_store}),
        fn ->
          Config.init([])
        end
    end
  end
end
