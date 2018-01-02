defmodule Expected do
  @moduledoc """
  A module for login and session management.
  """

  import Plug.Conn,
    only: [
      get_req_header: 2,
      put_private: 3,
      put_resp_cookie: 4,
      register_before_send: 2
    ]

  alias Expected.Login

  @behaviour Plug

  @cookie_max_age 7_776_000

  #################
  # API functions #
  #################

  @doc """
  Lists the logins for the given `username`.
  """
  @spec list_user_logins(String.t()) :: [Login.t()]
  def list_user_logins(username) do
    %{store: store, store_opts: store_opts} = fetch_stores!()
    store.list_user_logins(username, store_opts)
  end

  @doc """
  Deletes a login given its `username` and `serial`.
  """
  @spec delete_login(String.t(), String.t()) :: :ok
  def delete_login(username, serial) do
    %{
      store: store,
      store_opts: store_opts,
      session_opts: %{store: session_store, store_config: session_config}
    } = fetch_stores!()

    case store.get(username, serial, store_opts) do
      {:ok, login} ->
        store.delete(username, serial, store_opts)
        session_store.delete(nil, login.sid, session_config)

      {:error, :no_login} ->
        :ok
    end
  end

  @doc """
  Cleans the old logins for the given `username`.
  """
  @spec clean_old_logins(String.t()) :: :ok
  def clean_old_logins(username) do
    %{store: store, store_opts: store_opts} = fetch_stores!()

    cookie_max_age =
      Application.get_env(:expected, :cookie_max_age, @cookie_max_age)

    max_age = System.convert_time_unit(cookie_max_age, :seconds, :native)
    oldest_valid_login = System.os_time() - max_age
    logins = store.list_user_logins(username, store_opts)

    Enum.each(logins, fn login ->
      if login.last_login < oldest_valid_login,
        do: store.delete(login.username, login.serial, store_opts)
    end)
  end

  @spec fetch_stores! :: map()
  defp fetch_stores! do
    case Application.fetch_env(:expected, :stores) do
      {:ok, stores} -> stores
      :error -> raise Expected.PlugError
    end
  end

  ##################
  # Plug functions #
  ##################

  @impl true
  def init(_opts) do
    %{}
    |> init_store()
    |> init_config()
    |> init_session()
    |> put_stores_env()
  end

  @spec init_store(map()) :: map()
  defp init_store(expected) do
    store = fetch_store!()

    store_opts =
      :expected
      |> Application.get_all_env()
      |> store.init()

    expected
    |> Map.put(:store, store)
    |> Map.put(:store_opts, store_opts)
  end

  @spec init_config(map()) :: map()
  defp init_config(expected) do
    expected
    |> Map.put(:auth_cookie, fetch_auth_cookie_name!())
  end

  @spec init_session(map()) :: map()
  defp init_session(expected) do
    session_cookie = fetch_session_cookie_name!()

    opts = [
      store: fetch_session_store!(),
      key: session_cookie
    ]

    other_opts = Application.get_env(:expected, :session_opts, [])
    session_opts = Plug.Session.init(opts ++ other_opts)

    expected
    |> Map.put(:session_opts, session_opts)
    |> Map.put(:session_cookie, session_cookie)
  end

  @spec put_stores_env(map()) :: map()
  defp put_stores_env(expected) do
    stores = %{
      store: expected.store,
      store_opts: expected.store_opts,
      session_opts: expected.session_opts
    }

    Application.put_env(:expected, :stores, stores)
    expected
  end

  @spec fetch_store! :: module()
  defp fetch_store! do
    case Application.fetch_env(:expected, :store) do
      {:ok, key} -> get_store(key)
      :error -> raise Expected.ConfigurationError, reason: :no_store
    end
  end

  @spec get_store(atom()) :: module()
  defp get_store(:memory), do: Expected.MemoryStore
  defp get_store(store), do: store

  @spec fetch_auth_cookie_name! :: String.t()
  defp fetch_auth_cookie_name! do
    case Application.fetch_env(:expected, :auth_cookie) do
      {:ok, auth_cookie} -> auth_cookie
      :error -> raise Expected.ConfigurationError, reason: :no_auth_cookie
    end
  end

  @spec fetch_session_store! :: atom()
  defp fetch_session_store! do
    case Application.fetch_env(:expected, :session_store) do
      {:ok, session_store} -> session_store
      :error -> raise Expected.ConfigurationError, reason: :no_session_store
    end
  end

  @spec fetch_session_cookie_name! :: String.t()
  defp fetch_session_cookie_name! do
    case Application.fetch_env(:expected, :session_cookie) do
      {:ok, session_cookie} -> session_cookie
      :error -> raise Expected.ConfigurationError, reason: :no_session_cookie
    end
  end

  @impl true
  def call(conn, opts) do
    conn
    |> put_private(:expected, opts)
    |> register_before_send(&before_send(&1))
    |> Plug.Session.call(opts.session_opts)
  end

  @spec before_send(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  defp before_send(conn, _opts \\ []) do
    expected = conn.private[:expected]
    do_before_send(conn, expected)
  end

  @spec do_before_send(Plug.Conn.t(), term()) :: Plug.Conn.t()

  defp do_before_send(conn, %{action: :register_login} = expected) do
    %{
      username: username,
      store: store,
      store_opts: store_opts,
      session_cookie: session_cookie
    } = expected

    login = %Login{
      username: username,
      serial: 48 |> :crypto.strong_rand_bytes() |> Base.encode64(),
      token: 48 |> :crypto.strong_rand_bytes() |> Base.encode64(),
      sid: conn.cookies[session_cookie],
      created_at: System.os_time(),
      last_login: System.os_time(),
      last_ip: conn.remote_ip,
      last_useragent: get_user_agent(conn)
    }

    store.put(login, store_opts)
    put_auth_cookie(conn, login)
  end

  defp do_before_send(conn, %{action: :update_login} = expected) do
    %{
      login: login,
      store: store,
      store_opts: store_opts,
      session_cookie: session_cookie
    } = expected

    login = %{
      login
      | token: 48 |> :crypto.strong_rand_bytes() |> Base.encode64(),
        sid: conn.cookies[session_cookie],
        last_login: System.os_time(),
        last_ip: conn.remote_ip,
        last_useragent: get_user_agent(conn)
    }

    store.put(login, store_opts)
    put_auth_cookie(conn, login)
  end

  defp do_before_send(conn, _) do
    conn
  end

  @spec get_user_agent(Plug.Conn.t()) :: String.t()
  defp get_user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [user_agent] -> user_agent
      _ -> ""
    end
  end

  @spec put_auth_cookie(Plug.Conn.t(), Login.t()) :: Plug.Conn.t()
  defp put_auth_cookie(conn, login) do
    auth_cookie_name = conn.private.expected.auth_cookie
    max_age = conn.private.expected.cookie_max_age
    auth_cookie = "#{login.username}.#{login.serial}.#{login.token}"

    put_resp_cookie(conn, auth_cookie_name, auth_cookie, max_age: max_age)
  end
end
