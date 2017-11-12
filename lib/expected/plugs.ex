defmodule Expected.Plugs do
  @moduledoc """
  Plugs for registering logins and authenticating persistent cookies.

  ## Requirements

  For the plugs in this module to work, you must plug `Expected.Config` in your
  endpoint, **before** `Plug.Session`:

      plug Expected.Config
      plug Plug.Session,
        key: "_my_app_key",
        store: PlugSessionMnesia.Store  # For instance, could be another one
  """

  import Plug.Conn, only: [get_session: 2, put_private: 3]

  @doc """
  Registers a login.

  ## Session store requirements

  For the login registration to work, this plug needs to get the session ID from
  the session cookie. **You must use a session store that stores the session
  server-side and uses the cookie to store the session ID:**

      plug Plug.Session,
        key: "_my_app_key",
        store: PlugSessionMnesia.Store  # For instance, could be another one.

  You must also precise the session cookie key in the configuration, matching
  with the one set in `Plug.Session`:

      config :expected,
        store: :mnesia,
        table: :expected,
        session_cookie: "_my_app_key"   # Same value as above.

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
        store: :mnesia,
        table: :expected,
        session_cookie: "_my_app_key",
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
        store: :mnesia,
        table: :expected,
        session_cookie: "_my_app_key",
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
    unless conn.private[:expected] == :initialised, do: raise Expected.PlugError

    expected = %{
      session_cookie: fetch_session_cookie_name!(opts),
      auth_cookie: get_option(opts, :auth_cookie, "expected"),
      cookie_max_age: get_option(opts, :cookie_max_age, 3 * 24 * 3600),
      username: fetch_username!(conn, opts)
    }

    put_private(conn, :expected, expected)
  end

  @spec fetch_session_cookie_name!(keyword) :: String.t
  defp fetch_session_cookie_name!(opts) do
    opts[:session_cookie] ||
    case Application.fetch_env(:expected, :session_cookie) do
      {:ok, key} -> key
      :error -> raise Expected.ConfigurationError, reason: :no_session_cookie
    end
  end

  @spec get_option(keyword, atom, term) :: String.t
  defp get_option(opts, key, default) do
    opts[key] || Application.get_env(:expected, key, default)
  end

  @spec fetch_username!(Plug.Conn.t, keyword) :: String.t
  defp fetch_username!(conn, opts) do
    plug_config = Application.get_env(:expected, :plug_config, [])

    current_user =
      opts[:current_user] ||
      Keyword.get(plug_config, :current_user, :current_user)

    username =
      opts[:username] ||
      Keyword.get(plug_config, :username, :username)

    case get_session(conn, current_user) do
      %{^username => current_username} -> current_username
      nil -> raise Expected.CurrentUserError
      _ -> raise Expected.InvalidUserError
    end
  end
end
