defmodule Expected.ConfigTest do
  use ExUnit.Case
  use Plug.Test

  alias Expected.Config

  setup do
    Application.put_env(:expected, :store, :memory)
    Application.put_env(:expected, :process_name, :test_store)
    Application.put_env(:expected, :session_store, :ets)
    Application.put_env(:expected, :session_cookie, "_test_key")
    Application.put_env(:expected, :session_opts, table: :test_session)

    on_exit fn ->
      Application.delete_env(:expected, :store)
      Application.delete_env(:expected, :process_name)
      Application.delete_env(:expected, :session_store)
      Application.delete_env(:expected, :session_cookie)
      Application.delete_env(:expected, :session_opts)
    end
  end

  describe "init/1" do
    ## Standard cases

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

    test "initialises the session" do
      assert %{session_opts: %{key: "_test_key", store_config: :test_session}} =
               Config.init([])
    end

    ## Problems

    test "raises an exception if the store is not configured" do
      Application.delete_env(:expected, :store)

      assert_raise Expected.ConfigurationError,
                   Expected.ConfigurationError.message(%{reason: :no_store}),
                   fn -> Config.init([]) end
    end

    test "raises an exception if the session store is not configured" do
      Application.delete_env(:expected, :session_store)

      assert_raise Expected.ConfigurationError,
                   Expected.ConfigurationError.message(%{
                     reason: :no_session_store
                   }),
                   fn -> Config.init([]) end
    end
  end
end
