defmodule Expected.PlugsTest do
  use Expected.Case

  import Expected.Plugs

  alias Expected.NotLoadedUser
  alias Expected.CurrentUserError
  alias Expected.InvalidUserError
  alias Expected.PlugError

  @one_minute_ago @now - System.convert_time_unit(60, :seconds, :native)

  @session_opts [
    store: :ets,
    key: @session_cookie,
    table: @ets_table
  ]

  @not_loaded_user %NotLoadedUser{username: "user"}
  @auth_cookie_content "user.serial.token"

  setup do
    setup_stores()

    conn =
      :get
      |> conn("/")
      |> Expected.call(Expected.init([]))

    on_exit fn ->
      Application.delete_env(:expected, :cookie_max_age)
      Application.delete_env(:expected, :plug_config)
    end

    %{conn: conn}
  end

  defp with_session(%{conn: conn}) do
    %{conn: fetch_session(conn)}
  end

  defp with_login(%{conn: conn}) do
    :ok = MemoryStore.put(@login, @server)
    %{conn: conn}
  end

  describe "register_login/2" do
    setup [:with_session]

    ## Standard cases

    test "creates a new login entry in the store if all is correcty configured",
         %{conn: conn} do
      conn =
        conn
        |> put_req_header("user-agent", "ExUnit")
        |> put_session(:current_user, %{username: "user"})
        |> register_login()
        |> send_resp(:ok, "")

      assert [%Login{} = login] = MemoryStore.list_user_logins("user", @server)
      assert login.username == "user"
      assert is_binary(login.serial)
      assert String.length(login.serial) != 0
      assert is_binary(login.token)
      assert String.length(login.token) != 0
      assert login.sid == conn.cookies[@session_cookie]
      assert login.created_at > @one_minute_ago
      assert login.last_login > @one_minute_ago
      assert login.last_ip == {127, 0, 0, 1}
      assert login.last_useragent == "ExUnit"
    end

    test "puts an auth_cookie if all is correctly configured", %{conn: conn} do
      conn =
        conn
        |> put_req_header("user-agent", "ExUnit")
        |> put_session(:current_user, %{username: "user"})
        |> register_login()
        |> send_resp(:ok, "")

      assert [%Login{} = login] = MemoryStore.list_user_logins("user", @server)
      assert conn.cookies[@auth_cookie] == "user.#{login.serial}.#{login.token}"
    end

    ## Configuration

    test "uses the current_user set in the application environment", %{
      conn: conn
    } do
      Application.put_env(:expected, :plug_config, current_user: :test_user)

      conn
      |> put_session(:current_user, %{username: "user"})
      |> put_session(:test_user, %{username: "test_user"})
      |> register_login()
      |> send_resp(:ok, "")

      assert [] = MemoryStore.list_user_logins("user", @server)
      assert [%Login{}] = MemoryStore.list_user_logins("test_user", @server)
    end

    test "uses preferably the current_user set in options", %{conn: conn} do
      Application.put_env(:expected, :plug_config, current_user: :test_user)

      conn
      |> put_session(:current_user, %{username: "user"})
      |> put_session(:test_user, %{username: "test_user"})
      |> put_session(:other_user, %{username: "other_user"})
      |> register_login(current_user: :other_user)
      |> send_resp(:ok, "")

      assert [] = MemoryStore.list_user_logins("user", @server)
      assert [] = MemoryStore.list_user_logins("test_user", @server)
      assert [%Login{}] = MemoryStore.list_user_logins("other_user", @server)
    end

    test "uses the username field set in the application environment", %{
      conn: conn
    } do
      Application.put_env(:expected, :plug_config, username: :user_id)

      conn
      |> put_session(:current_user, %{username: "user", user_id: "user_id"})
      |> register_login()
      |> send_resp(:ok, "")

      assert [] = MemoryStore.list_user_logins("user", @server)

      assert [%Login{username: "user_id"}] =
               MemoryStore.list_user_logins("user_id", @server)
    end

    test "uses preferably the username field set in options", %{conn: conn} do
      Application.put_env(:expected, :plug_config, username: :user_id)

      user = %{username: "user", user_id: "user_id", id: "id"}

      conn
      |> put_session(:current_user, user)
      |> register_login(username: :id)
      |> send_resp(:ok, "")

      assert [] = MemoryStore.list_user_logins("user", @server)
      assert [] = MemoryStore.list_user_logins("user_id", @server)

      assert [%Login{username: "id"}] =
               MemoryStore.list_user_logins("id", @server)
    end

    test "uses the auth_cookie max age set in the application environment", %{
      conn: conn
    } do
      Application.put_env(:expected, :cookie_max_age, 7)

      conn =
        conn
        |> put_session(:current_user, %{username: "user"})
        |> register_login()
        |> send_resp(:ok, "")

      assert conn |> get_resp_header("set-cookie") |> Enum.join() =~ "max-age=7"
    end

    test "uses preferably the auth_cookie max age set in options", %{
      conn: conn
    } do
      Application.put_env(:expected, :cookie_max_age, 7)

      conn =
        conn
        |> put_session(:current_user, %{username: "user"})
        |> register_login(cookie_max_age: 9)
        |> send_resp(:ok, "")

      assert conn |> get_resp_header("set-cookie") |> Enum.join() =~ "max-age=9"
      refute conn |> get_resp_header("set-cookie") |> Enum.join() =~ "max-age=7"
    end

    ## Problems

    test "raises an exception if `Expected` has not been plugged" do
      assert_raise PlugError, fn ->
        :get
        |> conn("/")
        |> Plug.Session.call(Plug.Session.init(@session_opts))
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
    setup [:with_login]

    ## Standard cases

    test "assigns :authenticated and :current_user if the session is already
          authenticated", %{conn: conn} do
      conn =
        conn
        |> fetch_session()
        |> put_session(:authenticated, true)
        |> put_session(:current_user, %{username: "user"})
        |> authenticate()

      assert conn.assigns[:authenticated] == true
      assert conn.assigns[:current_user] == %{username: "user"}
    end

    test "does not process the auth_cookie if the session is already
          authenticated", %{conn: conn} do
      conn =
        conn
        |> put_req_cookie(@auth_cookie, @auth_cookie_content)
        |> fetch_session()
        |> put_session(:authenticated, true)
        |> put_session(:current_user, %{username: "other_user"})
        |> authenticate()

      assert conn.assigns[:authenticated] == true
      assert conn.assigns[:current_user] == %{username: "other_user"}
    end

    test "authenticates from the auth_cookie if the session is not yet
          authenticated", %{conn: conn} do
      conn =
        conn
        |> put_req_cookie(@auth_cookie, @auth_cookie_content)
        |> fetch_session()
        |> authenticate()

      assert conn.assigns[:authenticated] == true
      assert conn.assigns[:current_user] == @not_loaded_user
      assert get_session(conn, :authenticated) == true
      assert get_session(conn, :current_user) == @not_loaded_user
    end

    test "updates the login and the cookie if the session is not yet
          authenticated and the current cookie is valid", %{conn: conn} do
      conn =
        conn
        |> put_req_cookie(@auth_cookie, @auth_cookie_content)
        |> fetch_session()
        |> authenticate()
        |> send_resp(:ok, "")

      [login] = MemoryStore.list_user_logins("user", @server)

      assert login.serial == @login.serial
      assert login.token != @login.token
      assert login.sid != @login.sid
      assert login.created_at == @login.created_at
      assert login.last_login > @login.last_login
      assert conn.cookies[@auth_cookie] == "user.#{login.serial}.#{login.token}"
    end

    test "deletes the old session from the store when authenticating from an
          auth_cookie", %{conn: conn} do
      session_conn =
        conn
        |> fetch_session()
        |> put_session("a", "b")
        |> send_resp(:ok, "")

      sid = session_conn.cookies[@session_cookie]

      assert {_, %{"a" => "b"}} = Plug.Session.ETS.get(nil, sid, @ets_table)

      login = %{@login | sid: sid}
      :ok = MemoryStore.put(login, @server)

      conn
      |> put_req_cookie(@auth_cookie, @auth_cookie_content)
      |> fetch_session()
      |> authenticate()
      |> send_resp(:ok, "")

      assert Plug.Session.ETS.get(nil, sid, @ets_table) == {nil, %{}}
    end

    test "creates a new session when authenticating from an auth_cookie", %{
      conn: conn
    } do
      conn1 =
        conn
        |> fetch_session()
        |> put_session(:test, :test)
        |> send_resp(:ok, "")

      sid1 = conn1.cookies[@session_cookie]

      login = %{@login | sid: sid1}
      :ok = MemoryStore.put(login, @server)

      conn2 =
        conn
        |> recycle_cookies(conn1)
        |> put_req_cookie(@auth_cookie, @auth_cookie_content)
        |> fetch_session()
        |> authenticate()
        |> send_resp(:ok, "")

      sid2 = conn2.cookies[@session_cookie]

      assert sid1 != sid2
    end

    test "cleans old user’s logins when authenticating from an auth_cookie", %{
      conn: conn
    } do
      :ok = MemoryStore.put(@old_login, @server)

      logins = MemoryStore.list_user_logins("user", @server)
      assert length(logins) == 2

      conn
      |> put_req_cookie(@auth_cookie, @auth_cookie_content)
      |> fetch_session()
      |> authenticate()

      logins = MemoryStore.list_user_logins("user", @server)
      assert length(logins) == 1
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

    test "uses the authenticated field set in the application environment", %{
      conn: conn
    } do
      Application.put_env(:expected, :plug_config, authenticated: :logged_in)

      conn =
        conn
        |> put_req_cookie(@auth_cookie, @auth_cookie_content)
        |> fetch_session()
        |> authenticate()

      assert conn.assigns[:authenticated] == nil
      assert conn.assigns[:logged_in] == true
      assert conn.assigns[:current_user] == @not_loaded_user
      assert get_session(conn, :authenticated) == nil
      assert get_session(conn, :logged_in) == true
      assert get_session(conn, :current_user) == @not_loaded_user
    end

    test "uses preferably the authenticated field set in options", %{
      conn: conn
    } do
      Application.put_env(:expected, :plug_config, authenticated: :logged_in)

      conn =
        conn
        |> put_req_cookie(@auth_cookie, @auth_cookie_content)
        |> fetch_session()
        |> authenticate(authenticated: :auth?)

      assert conn.assigns[:authenticated] == nil
      assert conn.assigns[:logged_in] == nil
      assert conn.assigns[:auth?] == true
      assert conn.assigns[:current_user] == @not_loaded_user
      assert get_session(conn, :authenticated) == nil
      assert get_session(conn, :logged_in) == nil
      assert get_session(conn, :auth?) == true
      assert get_session(conn, :current_user) == @not_loaded_user
    end

    test "uses the current_user set in the application environment", %{
      conn: conn
    } do
      Application.put_env(:expected, :plug_config, current_user: :user_id)

      conn =
        conn
        |> put_req_cookie(@auth_cookie, @auth_cookie_content)
        |> fetch_session()
        |> authenticate()

      assert conn.assigns[:authenticated] == true
      assert conn.assigns[:current_user] == nil
      assert conn.assigns[:user_id] == @not_loaded_user
      assert get_session(conn, :authenticated) == true
      assert get_session(conn, :current_user) == nil
      assert get_session(conn, :user_id) == @not_loaded_user
    end

    test "uses preferably the current_user set in options", %{conn: conn} do
      Application.put_env(:expected, :plug_config, current_user: :user_id)

      conn =
        conn
        |> put_req_cookie(@auth_cookie, @auth_cookie_content)
        |> fetch_session()
        |> authenticate(current_user: :id)

      assert conn.assigns[:authenticated] == true
      assert conn.assigns[:current_user] == nil
      assert conn.assigns[:user_id] == nil
      assert conn.assigns[:id] == @not_loaded_user
      assert get_session(conn, :authenticated) == true
      assert get_session(conn, :current_user) == nil
      assert get_session(conn, :user_id) == nil
      assert get_session(conn, :id) == @not_loaded_user
    end

    test "uses the auth_cookie max age set in the application environment", %{
      conn: conn
    } do
      Application.put_env(:expected, :cookie_max_age, 7)

      conn =
        conn
        |> put_req_cookie(@auth_cookie, @auth_cookie_content)
        |> fetch_session()
        |> authenticate()
        |> send_resp(:ok, "")

      assert conn |> get_resp_header("set-cookie") |> Enum.join() =~ "max-age=7"
    end

    test "uses preferably the auth_cookie max age set in options", %{
      conn: conn
    } do
      Application.put_env(:expected, :cookie_max_age, 7)

      conn =
        conn
        |> put_req_cookie(@auth_cookie, @auth_cookie_content)
        |> fetch_session()
        |> authenticate(cookie_max_age: 9)
        |> send_resp(:ok, "")

      assert conn |> get_resp_header("set-cookie") |> Enum.join() =~ "max-age=9"
      refute conn |> get_resp_header("set-cookie") |> Enum.join() =~ "max-age=7"
    end

    ## Problems

    test "does not authenticate if the auth_cookie is invalid", %{conn: conn} do
      conn =
        conn
        |> put_req_cookie(@auth_cookie, "something")
        |> fetch_session()
        |> authenticate()

      assert conn.assigns[:authenticated] == nil
      assert conn.assigns[:current_user] == nil
      assert get_session(conn, :authenticated) == nil
      assert get_session(conn, :current_user) == nil
    end

    test "deletes the auth_cookie if it is invalid", %{conn: conn} do
      conn =
        conn
        |> put_req_cookie(@auth_cookie, "something")
        |> fetch_session()
        |> authenticate()
        |> send_resp(:ok, "")

      assert conn.cookies[@auth_cookie] == nil
    end

    test "does not authenticate if the auth_cookie does not reference a valid
          login", %{conn: conn} do
      conn =
        conn
        |> put_req_cookie(@auth_cookie, "some_user.some_serial.some_token")
        |> fetch_session()
        |> authenticate()

      assert conn.assigns[:authenticated] == nil
      assert conn.assigns[:current_user] == nil
      assert get_session(conn, :authenticated) == nil
      assert get_session(conn, :current_user) == nil
    end

    test "deletes the auth_cookie if it does not reference a valid login", %{
      conn: conn
    } do
      conn =
        conn
        |> put_req_cookie(@auth_cookie, "some_user.some_serial.some_token")
        |> fetch_session()
        |> authenticate()
        |> send_resp(:ok, "")

      assert conn.cookies[@auth_cookie] == nil
    end

    test "puts a flag if there is a valid serial but the token is not the
          expected one", %{conn: conn} do
      conn =
        conn
        |> put_req_cookie(@auth_cookie, "user.serial.bad_token")
        |> fetch_session()
        |> authenticate()

      assert conn.private[:unexpected_token] == true
      assert conn.assigns[:authenticated] == nil
      assert conn.assigns[:current_user] == nil
      assert get_session(conn, :authenticated) == nil
      assert get_session(conn, :current_user) == nil
    end

    test "deletes the auth_cookie if the token does not match", %{conn: conn} do
      conn =
        conn
        |> put_req_cookie(@auth_cookie, "user.serial.bad_token")
        |> fetch_session()
        |> authenticate()
        |> send_resp(:ok, "")

      assert conn.cookies[@auth_cookie] == nil
    end

    test "delete all the user’s logins if the token does not match", %{
      conn: conn
    } do
      conn
      |> put_req_cookie(@auth_cookie, "user.serial.bad_token")
      |> fetch_session()
      |> authenticate()

      assert MemoryStore.list_user_logins("user", @server) == []
    end

    test "raises an exception if `Expected` has not been plugged" do
      assert_raise PlugError, fn ->
        :get
        |> conn("/")
        |> Plug.Session.call(Plug.Session.init(@session_opts))
        |> fetch_session()
        |> authenticate()
        |> send_resp(:ok, "")
      end
    end
  end
end
