defmodule Expected.PlugsTest do
  use ExUnit.Case
  use Plug.Test

  import Expected.Plugs

  alias Expected.Login
  alias Expected.MemoryStore

  @session_cookie "_test_key"
  @auth_cookie "expected"
  @ets_table :test_session
  @server :test_store
  @session_opts [
    store: :ets,
    key: @session_cookie,
    table: @ets_table,
  ]

  setup do
    Application.put_env(:expected, :store, :memory)
    Application.put_env(:expected, :process_name, @server)
    Application.put_env(:expected, :session_store, :ets)
    Application.put_env(:expected, :session_cookie, @session_cookie)
    Application.put_env(:expected, :session_opts, table: :test_session)

    :ets.new(@ets_table, [:named_table, :public])
    MemoryStore.start_link()

    conn =
      :get
      |> conn("/")
      |> Expected.Config.call(Expected.Config.init([]))
      |> fetch_session()

    on_exit fn ->
      Application.delete_env(:expected, :auth_cookie)
      Application.delete_env(:expected, :cookie_max_age)
      Application.delete_env(:expected, :plug_config)
    end

    %{conn: conn}
  end

  describe "register_login/2" do

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
      assert login.persistent? == false
      assert %DateTime{} = login.created_at
      assert %DateTime{} = login.last_login
      assert login.last_ip == {127, 0, 0, 1}
      assert login.last_useragent == "ExUnit"
    end

    test "creates a persistent login entry if persistent_login is set to true",
         %{conn: conn} do
      conn =
        conn
        |> put_session(:current_user, %{username: "user"})
        |> assign(:persistent_login, true)
        |> register_login()
        |> send_resp(:ok, "")

      assert [%Login{username: "user", persistent?: true} = login] =
        MemoryStore.list_user_logins("user", @server)

      assert conn.cookies[@auth_cookie] == "user.#{login.serial}.#{login.token}"
    end

    ## Configuration

    test "fetches the session key from the session cookie set in options" do
      session_opts = Keyword.replace(@session_opts, :key, "_other_key")

      conn =
        :get
        |> conn("/")
        |> Expected.Config.call(Expected.Config.init([]))
        |> Plug.Session.call(Plug.Session.init(session_opts))
        |> fetch_session()
        |> put_session(:current_user, %{username: "user"})
        |> register_login(session_cookie: "_other_key")
        |> send_resp(:ok, "")

      assert [%Login{} = login] = MemoryStore.list_user_logins("user", @server)
      assert login.sid == conn.cookies["_other_key"]
    end

    test "uses the current_user set in the application environment",
         %{conn: conn} do
      Application.put_env(:expected, :plug_config, [current_user: :test_user])

      conn
      |> put_session(:current_user, %{username: "user"})
      |> put_session(:test_user, %{username: "test_user"})
      |> register_login()
      |> send_resp(:ok, "")

      assert [] = MemoryStore.list_user_logins("user", @server)
      assert [%Login{}] = MemoryStore.list_user_logins("test_user", @server)
    end

    test "uses preferably the current_user set in options", %{conn: conn} do
      Application.put_env(:expected, :plug_config, [current_user: :test_user])

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

    test "uses the username field set in the application environment",
         %{conn: conn} do
      Application.put_env(:expected, :plug_config, [username: :user_id])

      conn
      |> put_session(:current_user, %{username: "user", user_id: "user_id"})
      |> register_login()
      |> send_resp(:ok, "")

      assert [] = MemoryStore.list_user_logins("user", @server)
      assert [%Login{username: "user_id"}] =
        MemoryStore.list_user_logins("user_id", @server)
    end

    test "uses preferably the username field set in options", %{conn: conn} do
      Application.put_env(:expected, :plug_config, [username: :user_id])

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

    test "uses the auth_cookie set in the application environment",
         %{conn: conn} do
      Application.put_env(:expected, :auth_cookie, "some_cookie")

      conn =
        conn
        |> put_session(:current_user, %{username: "user"})
        |> assign(:persistent_login, true)
        |> register_login()
        |> send_resp(:ok, "")

      assert [%Login{} = login] = MemoryStore.list_user_logins("user", @server)
      assert conn.cookies["some_cookie"] ==
        "user.#{login.serial}.#{login.token}"
    end

    test "uses preferably the auth_cookie set in options", %{conn: conn} do
      Application.put_env(:expected, :auth_cookie, "some_cookie")

      conn =
        conn
        |> put_session(:current_user, %{username: "user"})
        |> assign(:persistent_login, true)
        |> register_login(auth_cookie: "other_cookie")
        |> send_resp(:ok, "")

      assert [%Login{} = login] = MemoryStore.list_user_logins("user", @server)
      assert conn.cookies["other_cookie"] ==
        "user.#{login.serial}.#{login.token}"
    end

    test "uses the auth_cookie max age set in the application environment",
         %{conn: conn} do
      Application.put_env(:expected, :cookie_max_age, 7)

      conn =
        conn
        |> put_session(:current_user, %{username: "user"})
        |> assign(:persistent_login, true)
        |> register_login()
        |> send_resp(:ok, "")

      assert conn |> get_resp_header("set-cookie") |> Enum.join() =~ "max-age=7"
    end

    test "uses preferably the auth_cookie max age set in options",
         %{conn: conn} do
      Application.put_env(:expected, :cookie_max_age, 7)

      conn =
        conn
        |> put_session(:current_user, %{username: "user"})
        |> assign(:persistent_login, true)
        |> register_login(cookie_max_age: 9)
        |> send_resp(:ok, "")

      assert conn |> get_resp_header("set-cookie") |> Enum.join() =~ "max-age=9"
      refute conn |> get_resp_header("set-cookie") |> Enum.join() =~ "max-age=7"
    end

    ## Problems

    test "raises an exception if `Expected.Config` has not been plugged" do
      assert_raise Expected.PlugError, fn ->
        :get
        |> conn("/")
        |> Plug.Session.call(Plug.Session.init(@session_opts))
        |> fetch_session()
        |> put_session(:current_user, %{username: "user"})
        |> register_login()
        |> send_resp(:ok, "")
      end
    end

    test "raises an exception if the session cookie is not configured",
        %{conn: conn} do
      Application.delete_env(:expected, :session_cookie)

      assert_raise Expected.ConfigurationError,
        Expected.ConfigurationError.message(%{reason: :no_session_cookie}),
        fn ->
          conn
          |> put_session(:current_user, %{username: "user"})
          |> register_login()
          |> send_resp(:ok, "")
        end
    end

    test "raises an exception if the session cookie is not present or empty",
        %{conn: conn} do
      Application.put_env(:expected, :session_cookie, "_other_key")

      assert_raise Expected.SessionError, fn ->
        conn
        |> put_session(:current_user, %{username: "user"})
        |> register_login()
        |> send_resp(:ok, "")
      end
    end

    test "raises an exception if the current_user is not set", %{conn: conn} do
      assert_raise Expected.CurrentUserError, fn -> register_login(conn) end
    end

    test "raises an exception if the current_user does not contain a username
          field", %{conn: conn} do
      assert_raise Expected.InvalidUserError, fn ->
        conn
        |> put_session(:current_user, %{})
        |> register_login()
        |> send_resp(:ok, "")
      end
    end
  end
end
