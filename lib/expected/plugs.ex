defmodule Expected.Plugs do
  @moduledoc """
  Plugs for registering logins and authenticating persistent cookies.

  ## Requirements

  For the plugs in this module to work, you must plug `Expected.Config` in your
  endpoint:

      plug Expected.Config

  As `Expected.Config` calls `Plug.Session`, you must not plug it in your
  endpoint.
  """

  import Plug.Conn, only: [get_session: 2, put_private: 3]

  @auth_cookie "expected"
  @cookie_max_age 7_776_000  # 3 months.

  @doc """
  Registers a login.

  ## Session store requirements

  For the login registration to work, this plug needs to get the session ID from
  the session cookie. **You must use a session store that stores the session
  server-side and uses the cookie to store the session ID:**

      config :expected,
        store: :mnesia,
        table: :expected,
        session_store: PlugSessionMnesia.Store,  # For instance.
        session_cookie: "_my_app_key",
        session_opts: [table: :session]

  ## Session requirements

  It also expects that the session contains a `:current_user` key featuring a
  `:username` field:

      conn
      |> put_session(:current_user, %User{username: "user", name: "A User"})
      |> register_login()

  The names of these fields can be changed by setting the corresponding options:

      conn
      |> put_session(:logged_in_user, %User{user_id: "user", name: "A User"})
      |> register_login(current_user: :logged_in_user, username: :user_id)

  They can also be set application-wide in the configuration:

      config :expected,
        ...
        plug_config: [current_user: :logged_in_user, username: :user_id]

  ## Persistent logins

  To make the login persistent, `conn.assigns.persistent_login` can be set to
  `true`:

      conn
      |> put_session(:current_user, %User{username: "user", name: "A User"})
      |> assign(:persistent_login, true)
      |> register_login()

  This field is not mandatory, though.

  Authentication information for persistent logins is stored in a cookie. By
  default, it is named `"expected"` and is valid for three months after the last
  successful authentication. You can change this parameters in the application
  configuration:

      config :expected,
        ...
        auth_cookie: "_my_app_auth",  # Set the authentication cookie name here.
        cookie_max_age: 86_400        # Set to one day, for example.

  Alternatively, you can set them locally:

      conn
      |> put_session(:current_user, %User{username: "user", name: "A User"})
      |> assign(:persistent_login, true)
      |> register_login(auth_cookie: "_my_app_auth", max_age: 86_400)
  """
  @spec register_login(Plug.Conn.t) :: Plug.Conn.t
  @spec register_login(Plug.Conn.t, keyword) :: Plug.Conn.t
  def register_login(conn, opts \\ []) do
    expected =
      conn
      |> fetch_expected!()
      |> put_cookies_opts(opts)
      |> Map.put(:username, fetch_username!(conn, opts))
      |> Map.put(:action, :register_login)

    put_private(conn, :expected, expected)
  end

  @spec fetch_expected!(Plug.Conn.t) :: map
  defp fetch_expected!(%{private: %{expected: expected}}), do: expected
  defp fetch_expected!(_), do: raise Expected.PlugError

  @spec put_cookies_opts(map, keyword) :: map
  defp put_cookies_opts(expected, opts) do
    env = Application.get_all_env(:expected)
    expected
    |> Map.put(:session_cookie, fetch_session_cookie_name!(opts))
    |> Map.put(:auth_cookie, get_option(opts, env, :auth_cookie, @auth_cookie))
    |> Map.put(:cookie_max_age, get_option(opts, env, :cookie_max_age,
      @cookie_max_age))
  end

  @spec fetch_session_cookie_name!(keyword) :: String.t
  defp fetch_session_cookie_name!(opts) do
    opts[:session_cookie] ||
    case Application.fetch_env(:expected, :session_cookie) do
      {:ok, key} -> key
      :error -> raise Expected.ConfigurationError, reason: :no_session_cookie
    end
  end

  @spec get_option(keyword, keyword, atom, term) :: term
  defp get_option(opts, config, key, default) do
    opts[key] || config[key] || default
  end

  @spec fetch_username!(Plug.Conn.t, keyword) :: String.t
  defp fetch_username!(conn, opts) do
    plug_config = Application.get_env(:expected, :plug_config, [])
    current_user = get_option(opts, plug_config, :current_user, :current_user)
    username = get_option(opts, plug_config, :username, :username)

    case get_session(conn, current_user) do
      %{^username => current_username} -> current_username
      nil -> raise Expected.CurrentUserError
      _ -> raise Expected.InvalidUserError
    end
  end
end
