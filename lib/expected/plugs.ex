defmodule Expected.Plugs do
  @moduledoc """
  Plugs for registering logins and authenticating persistent cookies.

  ## Requirements

  For the plugs in this module to work, you must plug `Expected` in your
  endpoint:

      plug Expected

  As `Expected` calls `Plug.Session` itself, you must not plug it in your
  endpoint. You must however configure the session in the `:expected`
  configuration:

      config :expected,
        store: :mnesia,
        table: :logins,
        auth_cookie: "_my_app_auth",
        session_store: PlugSessionMnesia.Store,  # For instance.
        session_cookie: "_my_app_key"  # The Plug.Session `:key` option.

  For the login registration to work, Expected needs to get the session ID from
  the session cookie. **You must use a session store that stores the session
  server-side and uses the cookie to store the session ID.**
  """

  import Plug.Conn,
    only: [
      assign: 3,
      configure_session: 2,
      delete_resp_cookie: 2,
      get_session: 2,
      put_private: 3,
      put_session: 3
    ]

  alias Expected.NotLoadedUser
  alias Expected.CurrentUserError
  alias Expected.InvalidUserError
  alias Expected.PlugError

  @cookie_max_age 7_776_000

  @doc """
  Registers a login.

  ## Requirements

  This plug expects that the session contains a `:current_user` key featuring a
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

  ## Authentication cookie

  Authentication information is stored in a cookie. By default, it is valid for
  90 days after the last successful authentication. You can change this in the
  application configuration:

      config :expected,
        ...
        cookie_max_age: 86_400  # Set to one day, for example.

  Alternatively, you can set it locally:

      conn
      |> put_session(:current_user, %User{username: "user", name: "A User"})
      |> assign(:persistent_login, true)
      |> register_login(cookie_max_age: 86_400)
  """
  @spec register_login(Plug.Conn.t()) :: Plug.Conn.t()
  @spec register_login(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def register_login(conn, opts \\ []) do
    expected =
      conn
      |> fetch_expected!()
      |> put_cookie_max_age(opts)
      |> Map.put(:username, fetch_username!(conn, opts))
      |> Map.put(:action, :register_login)

    put_private(conn, :expected, expected)
  end

  @doc """
  Logs a user out.

  This plug deletes the login and its associated session from the stores and
  their cookies. If there is no authentication cookie, it does nothing.
  """
  @spec logout(Plug.Conn.t()) :: Plug.Conn.t()
  @spec logout(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def logout(conn, _opts \\ []) do
    expected = fetch_expected!(conn)
    auth_cookie = conn.cookies[expected.auth_cookie]

    case parse_auth_cookie(auth_cookie) do
      {:ok, user, serial, _token} ->
        Expected.delete_login(user, serial)

        conn
        |> delete_resp_cookie(expected.session_cookie)
        |> delete_resp_cookie(expected.auth_cookie)

      _ ->
        delete_resp_cookie(conn, expected.auth_cookie)
    end
  end

  @doc """
  Authenticates a connection.

  ## Session authentication

  This plug first checks if the session is already authenticated. It does so by
  reading the `:authenticated` field in the session. If it is `true`, it assigns
  `:authenticated` and `:current_user` in the `conn` according to their value
  in the session.

  The names of these fields can be changed by setting the corresponding options:

      conn
      |> authenticate(authenticated: :logged_in, current_user: :user_id)

  They can also be set application-wide in the configuration:

      config :expected,
        ...
        plug_config: [authenticated: :logged_in, current_user: :user_id]

  ## Cookie authentication

  If the session is not yet authenticated, this plug checks for an
  authentication cookie. By default, it is valid for 90 days after the last
  successful authentication. You can change this in the application
  configuration:

      config :expected,
        ...
        cookie_max_age: 86_400  # Set to one day, for example.

  Alternatively, you can set it locally:

      conn
      |> authenticate(cookie_max_age: 86_400)

  ## Alerts

  For security purpose, an authentication cookie can be used only once. If an
  authentication cookie is re-used, `conn.assigns.unexpected_token` is set to
  `true` and the session is not authenticated. You can check this value using
  `Expected.unexpected_token?/1` and accordingly inform the user of a possible
  malicious access.

  ## User loading

  After a successful cookie authentication, the `:current_user` field in both
  the session and the `conn` assigns is set to an `Expected.NotLoadedUser`,
  featuring the user’s username:

      %Expected.NotLoadedUser{username: "user"}

  You should load this user from the database in another plug following this one
  if the session has been authenticated.
  """
  @spec authenticate(Plug.Conn.t()) :: Plug.Conn.t()
  @spec authenticate(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def authenticate(conn, opts \\ []) do
    expected = fetch_expected!(conn)
    plug_config = Application.get_env(:expected, :plug_config, [])

    authenticated_field =
      get_option(opts, plug_config, :authenticated, :authenticated)

    current_user_field =
      get_option(opts, plug_config, :current_user, :current_user)

    auth_cookie = conn.cookies[expected.auth_cookie]

    with auth when auth != true <- get_session(conn, :authenticated),
         {:ok, user, serial, token} <- parse_auth_cookie(auth_cookie),
         {:ok, login} <- expected.store.get(user, serial, expected.store_opts),
         %{username: ^user, token: ^token} <- login do
      session_store = expected.session_opts.store
      session_store.delete(nil, login.sid, expected.session_opts.store_config)

      not_loaded_user = %NotLoadedUser{username: user}

      expected =
        expected
        |> put_cookie_max_age(opts)
        |> Map.put(:login, login)
        |> Map.put(:action, :update_login)

      conn
      |> configure_session(renew: true)
      |> put_session(authenticated_field, true)
      |> put_session(current_user_field, not_loaded_user)
      |> assign(authenticated_field, true)
      |> assign(current_user_field, not_loaded_user)
      |> put_private(:expected, expected)
    else
      true ->
        put_auth(conn, authenticated_field, current_user_field)

      {:error, :no_cookie} ->
        conn

      {:error, :invalid} ->
        delete_resp_cookie(conn, expected.auth_cookie)

      {:error, :no_login} ->
        delete_resp_cookie(conn, expected.auth_cookie)

      %{username: username, token: _token} ->
        Expected.delete_all_user_logins(username)

        conn
        |> put_private(:unexpected_token, true)
        |> delete_resp_cookie(expected.auth_cookie)
    end
  end

  @spec fetch_expected!(Plug.Conn.t()) :: map()
  defp fetch_expected!(%{private: %{expected: expected}}), do: expected
  defp fetch_expected!(_), do: raise(PlugError)

  @spec parse_auth_cookie(String.t()) ::
          {:ok, String.t(), String.t(), String.t()}
          | {:error, :invalid}
  defp parse_auth_cookie(auth_cookie) when is_binary(auth_cookie) do
    with [encoded_user, serial, token] <- String.split(auth_cookie, "."),
         {:ok, user} <- Base.decode64(encoded_user) do
      {:ok, user, serial, token}
    else
      _ -> {:error, :invalid}
    end
  end

  defp parse_auth_cookie(nil), do: {:error, :no_cookie}
  defp parse_auth_cookie(_), do: {:error, :invalid}

  @spec put_auth(Plug.Conn.t(), atom(), atom()) :: Plug.Conn.t()
  defp put_auth(conn, authenticated_field, current_user_field) do
    conn
    |> assign(authenticated_field, true)
    |> assign(current_user_field, get_session(conn, current_user_field))
  end

  @spec put_cookie_max_age(map(), keyword()) :: map()
  defp put_cookie_max_age(expected, opts) do
    env = Application.get_all_env(:expected)
    cookie_max_age = get_option(opts, env, :cookie_max_age, @cookie_max_age)
    Map.put(expected, :cookie_max_age, cookie_max_age)
  end

  @spec get_option(keyword(), keyword(), atom(), term()) :: term()
  defp get_option(opts, config, key, default) do
    opts[key] || config[key] || default
  end

  @spec fetch_username!(Plug.Conn.t(), keyword()) :: String.t()
  defp fetch_username!(conn, opts) do
    plug_config = Application.get_env(:expected, :plug_config, [])
    current_user = get_option(opts, plug_config, :current_user, :current_user)
    username = get_option(opts, plug_config, :username, :username)

    case get_session(conn, current_user) do
      %{^username => current_username} -> current_username
      nil -> raise CurrentUserError
      _ -> raise InvalidUserError
    end
  end
end
