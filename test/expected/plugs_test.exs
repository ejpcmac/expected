defmodule Expected.PlugsTest do
  use Expected.Case

  import Expected.Plugs

  alias Expected.NotLoadedUser
  alias Expected.CurrentUserError
  alias Expected.InvalidUserError
  alias Expected.PlugError
  alias Plug.Session
  alias Plug.Session.ETS, as: SessionStore

  @one_minute_ago @now - System.convert_time_unit(60, :seconds, :native)

  @session_opts [
    store: :ets,
    key: @session_cookie,
    table: @ets_table
  ]

  setup do
    setup_stores()

    conn =
      :get
      |> conn("/")
      |> Expected.call(Expected.init([]))

    on_exit(fn ->
      Application.delete_env(:expected, :cookie_max_age)
      Application.delete_env(:expected, :plug_config)
    end)

    %{conn: conn}
  end

  defp with_session(%{conn: conn}) do
    %{conn: fetch_session(conn)}
  end

  defp auth_cookie(%Login{username: username, serial: serial, token: token}) do
    "#{Base.encode64(username)}.#{serial}.#{token}"
  end

  describe "register_login/2" do
    setup [:with_session]

    ## Standard cases

    property "creates a new login entry in the store if all is correcty
              configured", %{conn: conn} do
      check all username <- username(),
                useragent <- string(:ascii) do
        conn =
          conn
          |> put_req_header("user-agent", useragent)
          |> put_session(:current_user, %{username: username})
          |> register_login()
          |> send_resp(:ok, "")

        assert [%Login{} = login] =
                 MemoryStore.list_user_logins(username, @server)

        assert login.username == username
        assert is_binary(login.serial)
        assert String.length(login.serial) != 0
        assert is_binary(login.token)
        assert String.length(login.token) != 0
        assert login.sid == conn.cookies[@session_cookie]
        assert login.created_at > @one_minute_ago
        assert login.last_login > @one_minute_ago
        assert login.last_ip == {127, 0, 0, 1}
        assert login.last_useragent == useragent
      end
    end

    property "puts an auth_cookie if all is correctly configured", %{
      conn: conn
    } do
      check all username <- username(),
                useragent <- string(:ascii) do
        conn =
          conn
          |> put_req_header("user-agent", useragent)
          |> put_session(:current_user, %{username: username})
          |> register_login()
          |> send_resp(:ok, "")

        assert [%Login{} = login] =
                 MemoryStore.list_user_logins(username, @server)

        assert conn.cookies[@auth_cookie] == auth_cookie(login)
      end
    end

    ## Configuration

    property "uses the current_user set in the application environment", %{
      conn: conn
    } do
      check all env_field <- atom(:alphanumeric),
                env_field != :current_user,
                username <- username(),
                env_username <- username(),
                env_username != username do
        Application.put_env(:expected, :plug_config, current_user: env_field)

        conn
        |> put_session(:current_user, %{username: username})
        |> put_session(env_field, %{username: env_username})
        |> register_login()
        |> send_resp(:ok, "")

        assert [] = MemoryStore.list_user_logins(username, @server)
        assert [%Login{}] = MemoryStore.list_user_logins(env_username, @server)
      end
    end

    property "uses preferably the current_user set in options", %{conn: conn} do
      check all env_field <- atom(:alphanumeric),
                opt_field <- atom(:alphanumeric),
                env_field != :current_user,
                opt_field != :current_user,
                opt_field != env_field,
                username <- username(),
                env_username <- username(),
                opt_username <- username(),
                env_username != username,
                opt_username != username,
                opt_username != env_username do
        Application.put_env(:expected, :plug_config, current_user: env_field)

        conn
        |> put_session(:current_user, %{username: username})
        |> put_session(env_field, %{username: env_username})
        |> put_session(opt_field, %{username: opt_username})
        |> register_login(current_user: opt_field)
        |> send_resp(:ok, "")

        assert [] = MemoryStore.list_user_logins(username, @server)
        assert [] = MemoryStore.list_user_logins(env_username, @server)
        assert [%Login{}] = MemoryStore.list_user_logins(opt_username, @server)
      end
    end

    property "uses the username field set in the application environment", %{
      conn: conn
    } do
      check all env_field <- atom(:alphanumeric),
                env_field != :username,
                username <- username(),
                env_username <- username(),
                env_username != username do
        Application.put_env(:expected, :plug_config, username: env_field)

        user = Map.put(%{username: username}, env_field, env_username)

        conn
        |> put_session(:current_user, user)
        |> register_login()
        |> send_resp(:ok, "")

        assert [] = MemoryStore.list_user_logins(username, @server)

        assert [%Login{username: ^env_username}] =
                 MemoryStore.list_user_logins(env_username, @server)
      end
    end

    property "uses preferably the username field set in options", %{
      conn: conn
    } do
      check all env_field <- atom(:alphanumeric),
                opt_field <- atom(:alphanumeric),
                env_field != :username,
                opt_field != :username,
                opt_field != env_field,
                username <- username(),
                env_username <- username(),
                opt_username <- username(),
                env_username != username,
                opt_username != username,
                opt_username != env_username do
        Application.put_env(:expected, :plug_config, username: env_field)

        user =
          %{username: username}
          |> Map.put(env_field, env_username)
          |> Map.put(opt_field, opt_username)

        conn
        |> put_session(:current_user, user)
        |> register_login(username: opt_field)
        |> send_resp(:ok, "")

        assert [] = MemoryStore.list_user_logins(username, @server)
        assert [] = MemoryStore.list_user_logins(env_username, @server)

        assert [%Login{username: ^opt_username}] =
                 MemoryStore.list_user_logins(opt_username, @server)
      end
    end

    property "uses the auth_cookie max age set in the application environment",
             %{conn: conn} do
      check all max_age <- integer(1..@three_months) do
        Application.put_env(:expected, :cookie_max_age, max_age)

        conn =
          conn
          |> put_session(:current_user, %{username: "user"})
          |> register_login()
          |> send_resp(:ok, "")

        assert conn |> get_resp_header("set-cookie") |> Enum.join() =~
                 "max-age=#{max_age}"
      end
    end

    property "uses preferably the auth_cookie max age set in options", %{
      conn: conn
    } do
      check all env_max_age <- integer(1..@three_months),
                opt_max_age <- integer(1..@three_months),
                opt_max_age != env_max_age do
        Application.put_env(:expected, :cookie_max_age, env_max_age)

        conn =
          conn
          |> put_session(:current_user, %{username: "user"})
          |> register_login(cookie_max_age: opt_max_age)
          |> send_resp(:ok, "")

        assert conn |> get_resp_header("set-cookie") |> Enum.join() =~
                 "max-age=#{opt_max_age}"

        refute conn |> get_resp_header("set-cookie") |> Enum.join() =~
                 "max-age=#{env_max_age}"
      end
    end

    ## Problems

    test "raises an exception if `Expected` has not been plugged" do
      assert_raise PlugError, fn ->
        :get
        |> conn("/")
        |> Session.call(Session.init(@session_opts))
        |> fetch_session()
        |> put_session(:current_user, %{username: "user"})
        |> register_login()
        |> send_resp(:ok, "")
      end
    end

    test "raises an exception if the current_user is not set", %{conn: conn} do
      assert_raise CurrentUserError, fn -> register_login(conn) end
    end

    test "raises an exception if the current_user does not contain a username
          field", %{conn: conn} do
      assert_raise InvalidUserError, fn ->
        conn
        |> put_session(:current_user, %{})
        |> register_login()
        |> send_resp(:ok, "")
      end
    end
  end

  describe "authenticate/2" do
    ## Standard cases

    property "assigns :authenticated and :current_user if the session is already
              authenticated", %{conn: conn} do
      check all username <- username() do
        conn =
          conn
          |> fetch_session()
          |> put_session(:authenticated, true)
          |> put_session(:current_user, %{username: username})
          |> authenticate()

        assert conn.assigns[:authenticated] == true
        assert conn.assigns[:current_user] == %{username: username}
      end
    end

    property "does not process the auth_cookie if the session is already
              authenticated", %{conn: conn} do
      check all login <- login(),
                other_username <- username() do
        conn =
          conn
          |> put_req_cookie(@auth_cookie, auth_cookie(login))
          |> fetch_session()
          |> put_session(:authenticated, true)
          |> put_session(:current_user, %{username: other_username})
          |> authenticate()

        assert conn.assigns[:authenticated] == true
        assert conn.assigns[:current_user] == %{username: other_username}
      end
    end

    property "authenticates from the auth_cookie if the session is not yet
              authenticated", %{conn: conn} do
      check all login <- login() do
        not_loaded_user = %NotLoadedUser{username: login.username}

        conn =
          conn
          |> put_req_cookie(@auth_cookie, auth_cookie(login))
          |> fetch_session()
          |> authenticate()

        assert conn.assigns[:authenticated] == true
        assert conn.assigns[:current_user] == not_loaded_user
        assert get_session(conn, :authenticated) == true
        assert get_session(conn, :current_user) == not_loaded_user
      end
    end

    property "updates the login and the cookie if the session is not yet
              authenticated and the current cookie is valid", %{conn: conn} do
      check all login <- login() do
        conn =
          conn
          |> put_req_cookie(@auth_cookie, auth_cookie(login))
          |> fetch_session()
          |> authenticate()
          |> send_resp(:ok, "")

        [new_login] = MemoryStore.list_user_logins(login.username, @server)

        assert new_login.serial == login.serial
        assert new_login.token != login.token
        assert new_login.sid != login.sid
        assert new_login.created_at == login.created_at
        assert new_login.last_login > login.last_login
        assert conn.cookies[@auth_cookie] == auth_cookie(new_login)
      end
    end

    property "deletes the old session from the store when authenticating from an
              auth_cookie", %{conn: conn} do
      check all login <- login(),
                key <- binary(min_length: 1),
                value <- binary(min_length: 1) do
        session_conn =
          conn
          |> fetch_session()
          |> put_session(key, value)
          |> send_resp(:ok, "")

        sid = session_conn.cookies[@session_cookie]

        assert {_, %{^key => ^value}} = SessionStore.get(nil, sid, @ets_table)

        login = %{login | sid: sid}
        :ok = MemoryStore.put(login, @server)

        conn
        |> put_req_cookie(@auth_cookie, auth_cookie(login))
        |> fetch_session()
        |> authenticate()
        |> send_resp(:ok, "")

        assert SessionStore.get(nil, sid, @ets_table) == {nil, %{}}
      end
    end

    property "creates a new session when authenticating from an auth_cookie", %{
      conn: conn
    } do
      check all login <- login(),
                key <- binary(min_length: 1),
                value <- binary(min_length: 1) do
        conn1 =
          conn
          |> fetch_session()
          |> put_session(key, value)
          |> send_resp(:ok, "")

        sid1 = conn1.cookies[@session_cookie]

        login = %{login | sid: sid1}
        :ok = MemoryStore.put(login, @server)

        conn2 =
          conn
          |> recycle_cookies(conn1)
          |> put_req_cookie(@auth_cookie, auth_cookie(login))
          |> fetch_session()
          |> authenticate()
          |> send_resp(:ok, "")

        sid2 = conn2.cookies[@session_cookie]

        assert sid1 != sid2
      end
    end

    test "does nothing if the session is not authenticated and there is no
          auth_cookie", %{conn: conn} do
      conn =
        conn
        |> fetch_session()
        |> authenticate()

      refute conn.assigns[:authenticated]
      assert conn.assigns[:current_user] == nil
    end

    ## Configuration

    property "uses the authenticated field set in the application environment",
             %{conn: conn} do
      check all env_field <- atom(:alphanumeric),
                env_field != :authenticated,
                login <- login() do
        Application.put_env(:expected, :plug_config, authenticated: env_field)

        conn =
          conn
          |> put_req_cookie(@auth_cookie, auth_cookie(login))
          |> fetch_session()
          |> authenticate()

        not_loaded_user = %NotLoadedUser{username: login.username}

        assert conn.assigns[:authenticated] == nil
        assert conn.assigns[env_field] == true
        assert conn.assigns[:current_user] == not_loaded_user
        assert get_session(conn, :authenticated) == nil
        assert get_session(conn, env_field) == true
        assert get_session(conn, :current_user) == not_loaded_user
      end
    end

    property "uses preferably the authenticated field set in options", %{
      conn: conn
    } do
      check all env_field <- atom(:alphanumeric),
                opt_field <- atom(:alphanumeric),
                env_field != :authenticated,
                opt_field != :authenticated,
                opt_field != env_field,
                login <- login() do
        Application.put_env(:expected, :plug_config, authenticated: env_field)

        conn =
          conn
          |> put_req_cookie(@auth_cookie, auth_cookie(login))
          |> fetch_session()
          |> authenticate(authenticated: opt_field)

        not_loaded_user = %NotLoadedUser{username: login.username}

        assert conn.assigns[:authenticated] == nil
        assert conn.assigns[env_field] == nil
        assert conn.assigns[opt_field] == true
        assert conn.assigns[:current_user] == not_loaded_user
        assert get_session(conn, :authenticated) == nil
        assert get_session(conn, env_field) == nil
        assert get_session(conn, opt_field) == true
        assert get_session(conn, :current_user) == not_loaded_user
      end
    end

    property "uses the current_user set in the application environment", %{
      conn: conn
    } do
      check all env_field <- atom(:alphanumeric),
                env_field != :current_user,
                login <- login() do
        Application.put_env(:expected, :plug_config, current_user: env_field)

        conn =
          conn
          |> put_req_cookie(@auth_cookie, auth_cookie(login))
          |> fetch_session()
          |> authenticate()

        not_loaded_user = %NotLoadedUser{username: login.username}

        assert conn.assigns[:authenticated] == true
        assert conn.assigns[:current_user] == nil
        assert conn.assigns[env_field] == not_loaded_user
        assert get_session(conn, :authenticated) == true
        assert get_session(conn, :current_user) == nil
        assert get_session(conn, env_field) == not_loaded_user
      end
    end

    property "uses preferably the current_user set in options", %{conn: conn} do
      check all env_field <- atom(:alphanumeric),
                opt_field <- atom(:alphanumeric),
                env_field != :current_user,
                opt_field != :current_user,
                opt_field != env_field,
                login <- login() do
        Application.put_env(:expected, :plug_config, current_user: env_field)

        conn =
          conn
          |> put_req_cookie(@auth_cookie, auth_cookie(login))
          |> fetch_session()
          |> authenticate(current_user: opt_field)

        not_loaded_user = %NotLoadedUser{username: login.username}

        assert conn.assigns[:authenticated] == true
        assert conn.assigns[:current_user] == nil
        assert conn.assigns[env_field] == nil
        assert conn.assigns[opt_field] == not_loaded_user
        assert get_session(conn, :authenticated) == true
        assert get_session(conn, :current_user) == nil
        assert get_session(conn, env_field) == nil
        assert get_session(conn, opt_field) == not_loaded_user
      end
    end

    property "uses the auth_cookie max age set in the application environment",
             %{conn: conn} do
      check all max_age <- integer(1..@three_months),
                login <- login() do
        Application.put_env(:expected, :cookie_max_age, max_age)

        conn =
          conn
          |> put_req_cookie(@auth_cookie, auth_cookie(login))
          |> fetch_session()
          |> authenticate()
          |> send_resp(:ok, "")

        assert conn |> get_resp_header("set-cookie") |> Enum.join() =~
                 "max-age=#{max_age}"
      end
    end

    property "uses preferably the auth_cookie max age set in options", %{
      conn: conn
    } do
      check all env_max_age <- integer(1..@three_months),
                opt_max_age <- integer(1..@three_months),
                opt_max_age != env_max_age,
                login <- login() do
        Application.put_env(:expected, :cookie_max_age, env_max_age)

        conn =
          conn
          |> put_req_cookie(@auth_cookie, auth_cookie(login))
          |> fetch_session()
          |> authenticate(cookie_max_age: opt_max_age)
          |> send_resp(:ok, "")

        assert conn |> get_resp_header("set-cookie") |> Enum.join() =~
                 "max-age=#{opt_max_age}"

        refute conn |> get_resp_header("set-cookie") |> Enum.join() =~
                 "max-age=#{env_max_age}"
      end
    end

    ## Problems

    property "does not authenticate if the auth_cookie is invalid", %{
      conn: conn
    } do
      check all invalid_cookie <- string(:ascii) do
        conn =
          conn
          |> put_req_cookie(@auth_cookie, invalid_cookie)
          |> fetch_session()
          |> authenticate()

        assert conn.assigns[:authenticated] == nil
        assert conn.assigns[:current_user] == nil
        assert get_session(conn, :authenticated) == nil
        assert get_session(conn, :current_user) == nil
      end
    end

    property "deletes the auth_cookie if it is invalid", %{conn: conn} do
      check all invalid_cookie <- string(:ascii) do
        conn =
          conn
          |> put_req_cookie(@auth_cookie, invalid_cookie)
          |> fetch_session()
          |> authenticate()
          |> send_resp(:ok, "")

        assert conn.cookies[@auth_cookie] == nil
      end
    end

    property "does not authenticate if the auth_cookie does not reference a
              valid login", %{conn: conn} do
      check all login <- login(store: false) do
        conn =
          conn
          |> put_req_cookie(@auth_cookie, auth_cookie(login))
          |> fetch_session()
          |> authenticate()

        assert conn.assigns[:authenticated] == nil
        assert conn.assigns[:current_user] == nil
        assert get_session(conn, :authenticated) == nil
        assert get_session(conn, :current_user) == nil
      end
    end

    property "deletes the auth_cookie if it does not reference a valid login",
             %{conn: conn} do
      check all login <- login(store: false) do
        conn =
          conn
          |> put_req_cookie(@auth_cookie, auth_cookie(login))
          |> fetch_session()
          |> authenticate()
          |> send_resp(:ok, "")

        assert conn.cookies[@auth_cookie] == nil
      end
    end

    property "puts a flag if there is a valid serial but the token is not the
          expected one", %{conn: conn} do
      check all login <- login() do
        token = 48 |> :crypto.strong_rand_bytes() |> Base.encode64()

        conn =
          conn
          |> put_req_cookie(@auth_cookie, auth_cookie(%{login | token: token}))
          |> fetch_session()
          |> authenticate()

        assert conn.private[:unexpected_token] == true
        assert conn.assigns[:authenticated] == nil
        assert conn.assigns[:current_user] == nil
        assert get_session(conn, :authenticated) == nil
        assert get_session(conn, :current_user) == nil
      end
    end

    property "deletes the auth_cookie if the token does not match", %{
      conn: conn
    } do
      check all login <- login() do
        token = 48 |> :crypto.strong_rand_bytes() |> Base.encode64()

        conn =
          conn
          |> put_req_cookie(@auth_cookie, auth_cookie(%{login | token: token}))
          |> fetch_session()
          |> authenticate()
          |> send_resp(:ok, "")

        assert conn.cookies[@auth_cookie] == nil
      end
    end

    property "delete all the user’s logins if the token does not match", %{
      conn: conn
    } do
      check all login <- login() do
        token = 48 |> :crypto.strong_rand_bytes() |> Base.encode64()

        assert MemoryStore.list_user_logins(login.username, @server) == [login]

        conn
        |> put_req_cookie(@auth_cookie, auth_cookie(%{login | token: token}))
        |> fetch_session()
        |> authenticate()

        assert MemoryStore.list_user_logins(login.username, @server) == []
      end
    end

    test "raises an exception if `Expected` has not been plugged" do
      assert_raise PlugError, fn ->
        :get
        |> conn("/")
        |> Session.call(Session.init(@session_opts))
        |> fetch_session()
        |> authenticate()
        |> send_resp(:ok, "")
      end
    end
  end

  describe "logout/2" do
    ## Standard cases

    property "deletes the login if there is a valid auth_cookie", %{
      conn: conn
    } do
      check all login <- login() do
        assert MemoryStore.list_user_logins(login.username, @server) == [login]

        conn
        |> put_req_cookie(@auth_cookie, auth_cookie(login))
        |> fetch_session()
        |> logout()

        assert MemoryStore.list_user_logins(login.username, @server) == []
      end
    end

    property "deletes the session if there is valid auth_cookie", %{
      conn: conn
    } do
      check all login <- login() do
        assert SessionStore.get(nil, login.sid, @ets_table) == {
                 login.sid,
                 %{username: login.username}
               }

        conn
        |> put_req_cookie(@auth_cookie, auth_cookie(login))
        |> fetch_session()
        |> logout()

        assert SessionStore.get(nil, login.sid, @ets_table) == {nil, %{}}
      end
    end

    property "deletes the auth cookie", %{conn: conn} do
      check all login <- login() do
        conn =
          conn
          |> put_req_cookie(@auth_cookie, auth_cookie(login))
          |> fetch_session()
          |> logout()
          |> send_resp(:ok, "")

        assert conn.cookies[@auth_cookie] == nil
      end
    end

    property "deletes the session cookie", %{conn: conn} do
      check all login <- login() do
        conn =
          conn
          |> put_req_cookie(@session_cookie, login.sid)
          |> put_req_cookie(@auth_cookie, auth_cookie(login))
          |> fetch_session()
          |> logout()
          |> send_resp(:ok, "")

        assert conn.cookies[@session_cookie] == nil
      end
    end

    ## Problems

    property "deletes the auth_cookie if it is invalid", %{conn: conn} do
      check all invalid_cookie <- string(:ascii) do
        conn =
          conn
          |> put_req_cookie(@auth_cookie, invalid_cookie)
          |> fetch_session()
          |> logout()
          |> send_resp(:ok, "")

        assert conn.cookies[@auth_cookie] == nil
      end
    end

    property "deletes the auth_cookie if it does not reference a valid login",
             %{conn: conn} do
      check all login <- login(store: false) do
        conn =
          conn
          |> put_req_cookie(@auth_cookie, auth_cookie(login))
          |> fetch_session()
          |> logout()
          |> send_resp(:ok, "")

        assert conn.cookies[@auth_cookie] == nil
      end
    end

    test "raises an exception if `Expected` has not been plugged" do
      assert_raise PlugError, fn ->
        :get
        |> conn("/")
        |> Session.call(Session.init(@session_opts))
        |> fetch_session()
        |> logout()
        |> send_resp(:ok, "")
      end
    end
  end
end
