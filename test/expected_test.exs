defmodule ExpectedTest do
  use Expected.Case

  alias Expected.ConfigurationError
  alias Plug.Session.ETS, as: SessionStore

  #################
  # API functions #
  #################

  defp with_login(_) do
    setup_stores()

    :ok = MemoryStore.put(@login, @server)
    :ok = MemoryStore.put(@other_login, @server)

    # Also put a valid session for @login.
    SessionStore.put(nil, @sid, %{"a" => "b"}, @ets_table)

    :ok
  end

  describe "unexpected_token?/1" do
    test "returns true if there has been an authentication attempt with a bad
          token" do
      conn =
        :get
        |> conn("/")
        |> assign(:unexpected_token, true)

      assert Expected.unexpected_token?(conn) == true
    end

    test "returns false if ther has not been an authentication attempt with a
          bad token" do
      conn = conn(:get, "/")
      assert Expected.unexpected_token?(conn) == false
    end
  end

  describe "list_user_logins/1" do
    setup [:with_login]

    test "lists logins for the given user" do
      assert Expected.list_user_logins(@username) == [@login]
    end
  end

  describe "delete_login/2" do
    setup [:with_login]

    test "deletes a login if it exists" do
      assert :ok = Expected.delete_login(@username, @serial)
      assert {:error, :no_login} = MemoryStore.get(@username, @serial, @server)
    end

    test "deletes the session associated with the login if it exists" do
      assert :ok = Expected.delete_login(@username, @serial)
      assert SessionStore.get(nil, "sid", @ets_table) == {nil, %{}}
    end

    test "does nothing if the login does not exist" do
      assert :ok = Expected.delete_login("false_user", "bad_serial")
    end
  end

  describe "delete_all_user_logins/1" do
    setup [:with_login]

    test "deletes all user logins for the given username" do
      assert :ok = Expected.delete_all_user_logins(@username)
      assert MemoryStore.list_user_logins(@username, @server) == []
    end

    test "deletes the sessions associated with the logins if they exist" do
      assert :ok = Expected.delete_all_user_logins(@username)
      assert SessionStore.get(nil, "sid", @ets_table) == {nil, %{}}
    end

    test "does nothing if the user has no login in the store" do
      assert :ok = Expected.delete_all_user_logins("false_user")
    end
  end

  describe "clean_old_logins/1" do
    setup [:with_login]

    test "deletes the logins older than max_age" do
      :ok = MemoryStore.put(@old_login, @server)

      assert :ok = Expected.clean_old_logins(@three_months)
      assert MemoryStore.list_user_logins(@username, @server) == [@login]
    end

    test "cleans the sessions associated with the old logins" do
      SessionStore.put(nil, "sid2", %{"a" => "b"}, @ets_table)
      :ok = MemoryStore.put(@old_login, @server)

      assert :ok = Expected.clean_old_logins(@three_months)
      assert SessionStore.get(nil, "sid2", @ets_table) == {nil, %{}}
    end
  end

  #########################
  # Application functions #
  #########################

  describe "init_config/0" do
    ## Standard cases

    test "gets the store module from the application environment" do
      assert %{store: Expected.MemoryStore} = Expected.init_config()
    end

    test "converts the :memory store to Expected.MemoryStore" do
      Application.put_env(:expected, :store, :memory)
      assert %{store: Expected.MemoryStore} = Expected.init_config()
    end

    test "converts the :mnesia store to Expected.MnesiaStore" do
      Application.put_env(:expected, :store, :mnesia)
      Application.put_env(:expected, :table, :logins)
      assert %{store: Expected.MnesiaStore} = Expected.init_config()
    end

    test "keeps unknown store as is" do
      Application.put_env(:expected, :store, Expected.MemoryStore)
      assert %{store: Expected.MemoryStore} = Expected.init_config()
    end

    test "gets the store configuration from the application environment" do
      assert %{store_opts: @server} = Expected.init_config()
    end

    test "gets the auth_cookie from the application environment" do
      assert %{auth_cookie: @auth_cookie} = Expected.init_config()
    end

    test "initialises the session" do
      assert %{
               session_opts: %{
                 key: @session_cookie,
                 store_config: @ets_table
               }
             } = Expected.init_config()
    end

    test "gets the session_cookie from the application environment" do
      assert %{session_cookie: @session_cookie} = Expected.init_config()
    end

    ## Problems

    test "raises an exception if the store is not configured" do
      Application.delete_env(:expected, :store)

      assert_raise ConfigurationError,
                   ConfigurationError.message(%{reason: :no_store}),
                   fn -> Expected.init_config() end
    end

    test "raises an exception if the authentication cookie is not configured" do
      Application.delete_env(:expected, :auth_cookie)

      assert_raise ConfigurationError,
                   ConfigurationError.message(%{reason: :no_auth_cookie}),
                   fn -> Expected.init_config() end
    end

    test "raises an exception if the session store is not configured" do
      Application.delete_env(:expected, :session_store)

      assert_raise ConfigurationError,
                   ConfigurationError.message(%{reason: :no_session_store}),
                   fn -> Expected.init_config() end
    end

    test "raises an exception if the session cookie is not configured" do
      Application.delete_env(:expected, :session_cookie)

      assert_raise ConfigurationError,
                   ConfigurationError.message(%{reason: :no_session_cookie}),
                   fn -> Expected.init_config() end
    end
  end
end
