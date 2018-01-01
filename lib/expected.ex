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

  @impl true
  def init(_opts) do
    %{}
    |> init_store()
    |> init_config()
    |> init_session()
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
