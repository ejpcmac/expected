defmodule ExpectedTest do
  use Expected.Case

  alias Expected.ConfigurationError

  #################
  # API functions #
  #################

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
    setup [:setup_stores]

    property "lists logins for the given user" do
      check all user <- username(),
                length <- integer(1..5),
                user_logins <- list_of(login(username: user), length: length),
                _other_logins <- list_of(login(), length: 5) do
        logins = Expected.list_user_logins(user)

        assert length(logins) == length

        Enum.each(user_logins, fn login ->
          assert login in logins
        end)
      end
    end
  end

  describe "delete_login/2" do
    setup [:setup_stores]

    property "deletes a login if it exists" do
      check all %{username: username, serial: serial} <- login() do
        assert {:ok, %Login{}} = MemoryStore.get(username, serial, @server)
        assert :ok = Expected.delete_login(username, serial)
        assert {:error, :no_login} = MemoryStore.get(username, serial, @server)
      end
    end

    property "deletes the session associated with the login if it exists" do
      check all %{username: username, serial: serial, sid: sid} <- login() do
        assert SessionStore.get(nil, sid, @ets_table) ==
                 {sid, %{username: username}}

        assert :ok = Expected.delete_login(username, serial)
        assert SessionStore.get(nil, sid, @ets_table) == {nil, %{}}
      end
    end

    property "does nothing if the login does not exist" do
      check all %{username: user, serial: serial} <- login(store: false) do
        assert :ok = Expected.delete_login(user, serial)
      end
    end
  end

  describe "delete_all_user_logins/1" do
    setup [:setup_stores]

    property "deletes all user logins for the given username" do
      check all user <- username(),
                _user_logins <- list_of(login(username: user), length: 5),
                _other_logins <- list_of(login(), length: 5) do
        assert user |> MemoryStore.list_user_logins(@server) |> length() == 5
        assert :ok = Expected.delete_all_user_logins(user)
        assert MemoryStore.list_user_logins(user, @server) == []
      end
    end

    property "deletes the sessions associated with the logins if they exist" do
      check all username <- username(),
                user_logins <- list_of(login(username: username), length: 5),
                _other_logins <- list_of(login(), length: 5) do
        Enum.each(user_logins, fn %Login{sid: sid} ->
          assert SessionStore.get(nil, sid, @ets_table) ==
                   {sid, %{username: username}}
        end)

        assert :ok = Expected.delete_all_user_logins(username)

        Enum.each(user_logins, fn %Login{sid: sid} ->
          assert SessionStore.get(nil, sid, @ets_table) == {nil, %{}}
        end)
      end
    end

    property "does nothing if the user has no login in the store" do
      check all username <- username() do
        assert :ok = Expected.delete_all_user_logins(username)
      end
    end
  end

  describe "clean_old_logins/1" do
    setup [:setup_stores]

    property "deletes the logins older than max_age" do
      check all max_age <- integer(1..@three_months),
                recent_logins <- list_of(login(max_age: max_age), length: 5),
                old_logins <- list_of(login(min_age: max_age), length: 5) do
        assert :ok = Expected.clean_old_logins(max_age)

        Enum.each(recent_logins, fn %{username: username, serial: serial} ->
          assert {:ok, %Login{}} = MemoryStore.get(username, serial, @server)
        end)

        Enum.each(old_logins, fn %{username: username, serial: serial} ->
          assert {:error, :no_login} =
                   MemoryStore.get(username, serial, @server)
        end)
      end
    end

    property "cleans the sessions associated with the old logins" do
      check all max_age <- integer(1..@three_months),
                recent_logins <- list_of(login(max_age: max_age), length: 5),
                old_logins <- list_of(login(min_age: max_age), length: 5) do
        assert :ok = Expected.clean_old_logins(max_age)

        Enum.each(recent_logins, fn %Login{username: username, sid: sid} ->
          assert SessionStore.get(nil, sid, @ets_table) ==
                   {sid, %{username: username}}
        end)

        Enum.each(old_logins, fn %Login{sid: sid} ->
          assert SessionStore.get(nil, sid, @ets_table) == {nil, %{}}
        end)
      end
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
