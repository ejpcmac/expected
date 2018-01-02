defmodule ExpectedTest do
  use Expected.Case

  describe "init/1" do
    ## Standard cases

    test "gets the store module from the application environment" do
      assert %{store: Expected.MemoryStore} = Expected.init([])
    end

    test "converts the :memory store to Expected.MemoryStore" do
      Application.put_env(:expected, :store, :memory)
      assert %{store: Expected.MemoryStore} = Expected.init([])
    end

    test "keeps unknown store as is" do
      Application.put_env(:expected, :store, Expected.MemoryStore)
      assert %{store: Expected.MemoryStore} = Expected.init([])
    end

    test "gets the store configuration from the application environment" do
      assert %{store_opts: @server} = Expected.init([])
    end

    test "gets the auth_cookie from the application environment" do
      assert %{auth_cookie: @auth_cookie} = Expected.init([])
    end

    test "initialises the session" do
      assert %{
               session_opts: %{
                 key: @session_cookie,
                 store_config: @ets_table
               }
             } = Expected.init([])
    end

    test "gets the session_cookie from the application environment" do
      assert %{session_cookie: @session_cookie} = Expected.init([])
    end

    ## Problems

    test "raises an exception if the store is not configured" do
      Application.delete_env(:expected, :store)

      assert_raise Expected.ConfigurationError,
                   Expected.ConfigurationError.message(%{reason: :no_store}),
                   fn -> Expected.init([]) end
    end

    test "raises an exception if the authentication cookie is not configured" do
      Application.delete_env(:expected, :auth_cookie)

      assert_raise Expected.ConfigurationError,
                   Expected.ConfigurationError.message(%{
                     reason: :no_auth_cookie
                   }),
                   fn -> Expected.init([]) end
    end

    test "raises an exception if the session store is not configured" do
      Application.delete_env(:expected, :session_store)

      assert_raise Expected.ConfigurationError,
                   Expected.ConfigurationError.message(%{
                     reason: :no_session_store
                   }),
                   fn -> Expected.init([]) end
    end

    test "raises an exception if the session cookie is not configured" do
      Application.delete_env(:expected, :session_cookie)

      assert_raise Expected.ConfigurationError,
                   Expected.ConfigurationError.message(%{
                     reason: :no_session_cookie
                   }),
                   fn -> Expected.init([]) end
    end
  end
end
