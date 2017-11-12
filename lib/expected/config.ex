defmodule Expected.Config do
  @moduledoc """
  A plug for configuring `Expected`.
  """

  import Plug.Conn, only: [
    get_req_header: 2,
    put_private: 3,
    put_resp_cookie: 4,
    register_before_send: 2
  ]

  alias Expected.Login

  @behaviour Plug

  @impl true
  def init(_opts) do
    case Application.fetch_env(:expected, :store) do
      {:ok, config_store} ->
        store = get_store(config_store)
        store_opts =
          :expected
          |> Application.get_all_env()
          |> store.init()

        %{store: store, store_opts: store_opts}

      :error ->
        raise Expected.ConfigurationError, reason: :no_store
    end
  end

  @spec get_store(atom) :: module
  defp get_store(store) do
    case store do
      :memory -> Expected.MemoryStore
      _ -> store
    end
  end

  @impl true
  def call(conn, opts) do
    conn
    |> register_before_send(&before_send(&1, opts))
    |> put_private(:expected, :initialised)
  end

  @spec before_send(Plug.Conn.t, map) :: Plug.Conn.t
  defp before_send(conn, %{store: store, store_opts: store_opts}) do
    case conn.private[:expected] do
      %{session_cookie: session_cookie, username: username} ->
        sid = conn.cookies[session_cookie]
        if is_nil(sid), do: raise Expected.SessionError

        user_agent = case get_req_header(conn, "user-agent") do
          [user_agent] -> user_agent
          _ -> ""
        end

        login = %Login{
          username: username,
          serial: 48 |> :crypto.strong_rand_bytes() |> Base.encode64(),
          token: 48 |> :crypto.strong_rand_bytes() |> Base.encode64(),
          sid: sid,
          persistent?: conn.assigns[:persistent_login] || false,
          created_at: DateTime.utc_now(),
          last_login: DateTime.utc_now(),
          last_ip: conn.remote_ip,
          last_useragent: user_agent
        }

        store.put(login, store_opts)
        put_auth_cookie(conn, login)

      _ ->
        conn
    end
  end

  @spec put_auth_cookie(Plug.Conn.t, Login.t) :: Plug.Conn.t
  defp put_auth_cookie(conn, %Login{persistent?: false}), do: conn
  defp put_auth_cookie(conn, login) do
    auth_cookie_name = conn.private.expected.auth_cookie
    max_age = conn.private.expected.cookie_max_age
    auth_cookie = "#{login.username}.#{login.serial}.#{login.token}"

    put_resp_cookie(conn, auth_cookie_name, auth_cookie, max_age: max_age)
  end
end
