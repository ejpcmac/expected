defmodule ExpectedTest do
  use Expected.Case

  #################
  # API functions #
  #################

  defp with_login(_) do
    setup_stores()
    Expected.init([])

    :ok = MemoryStore.put(@login, @server)
    :ok = MemoryStore.put(@other_login, @server)

    # Also put a valid session for @login.
    Plug.Session.ETS.put(nil, "sid", %{"a" => "b"}, @ets_table)

    :ok
  end

  describe "list_user_logins/1" do
    setup [:with_login]

    test "lists logins for the given user" do
      assert Expected.list_user_logins("user") == [@login]
    end

    test "raises an exception if Expected has not been plugged" do
      Application.delete_env(:expected, :stores)

      assert_raise Expected.PlugError, fn ->
        Expected.list_user_logins("user")
      end
    end
  end

  describe "delete_login/2" do
    setup [:with_login]

    test "deletes a login if it exists" do
      assert :ok = Expected.delete_login("user", "serial")
      assert {:error, :no_login} = MemoryStore.get("user", "serial", @server)
    end

    test "deletes the session associated with the login if it exists" do
      assert :ok = Expected.delete_login("user", "serial")
      assert Plug.Session.ETS.get(nil, "sid", @ets_table) == {nil, %{}}
    end

    test "does nothing if the login does not exist" do
      assert :ok = Expected.delete_login("false_user", "bad_serial")
    end

    test "raises an exception if Expected has not been plugged" do
      Application.delete_env(:expected, :stores)

      assert_raise Expected.PlugError, fn ->
        Expected.delete_login("user", "serial")
      end
    end
  end

  describe "clean_old_logins/1" do
    setup [:with_login]

    test "cleans old logins for a given user" do
      :ok = MemoryStore.put(@old_login, @server)
      :ok = MemoryStore.put(@not_so_old_login, @server)

      assert :ok = Expected.clean_old_logins("user")
      assert Expected.list_user_logins("user") == [@login, @not_so_old_login]
    end

    test "gets the authentication cookie max age from the application
          environment" do
      Application.put_env(:expected, :cookie_max_age, 10)

      :ok = MemoryStore.put(@old_login, @server)
      :ok = MemoryStore.put(@not_so_old_login, @server)

      assert :ok = Expected.clean_old_logins("user")
      assert Expected.list_user_logins("user") == [@login]
    end

    test "raises an exception if Expected has not been plugged" do
      Application.delete_env(:expected, :stores)

      assert_raise Expected.PlugError, fn ->
        Expected.clean_old_logins("user")
      end
    end
  end

  ##################
  # Plug functions #
  ##################

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

    test "puts stores configuration in the application environment" do
      Expected.init([])

      assert {:ok, stores} = Application.fetch_env(:expected, :stores)
      assert stores.store == Expected.MemoryStore
      assert stores.store_opts == @server

      assert %{
               store: Plug.Session.ETS,
               key: @session_cookie,
               store_config: @ets_table
             } = stores.session_opts
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
