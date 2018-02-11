defmodule Expected.Case do
  @moduledoc """
  A test case for Expected.
  """

  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case
      use ExUnitProperties
      use Plug.Test

      alias Expected.Login
      alias Expected.MemoryStore
      alias Plug.Session.ETS, as: SessionStore

      @server :test_store
      @auth_cookie "_test_auth"
      @session_cookie "_test_key"
      @ets_table :test_session

      @now System.os_time()
      @three_months 7_776_000
      @four_months System.convert_time_unit(10_368_000, :seconds, :native)
      @four_months_ago @now - @four_months

      @username "user"
      @serial "serial"
      @token "token"
      @sid "sid"
      @login %Login{
        username: @username,
        serial: @serial,
        token: @token,
        sid: @sid,
        created_at: @now,
        last_login: @now,
        last_ip: {127, 0, 0, 1},
        last_useragent: "ExUnit"
      }

      @other_login %{@login | username: "user2", sid: "sid2"}

      @old_login %{
        @login
        | serial: "serial2",
          sid: "sid2",
          last_login: @four_months_ago
      }

      setup do
        Application.put_env(:expected, :store, :memory)
        Application.put_env(:expected, :process_name, @server)
        Application.put_env(:expected, :auth_cookie, @auth_cookie)
        Application.put_env(:expected, :session_store, :ets)
        Application.put_env(:expected, :session_opts, table: @ets_table)
        Application.put_env(:expected, :session_cookie, @session_cookie)

        on_exit(fn ->
          Application.delete_env(:expected, :stores)
          Application.delete_env(:expected, :cookie_max_age)
        end)
      end

      defp setup_stores(_ \\ :ok) do
        :ets.new(@ets_table, [:named_table, :public])
        start_supervised!(MemoryStore)
        :ok
      end

      # Username generator
      defp username, do: string(:ascii, min_length: 3)

      # Login generator
      defp login(opts \\ []) do
        now = System.os_time()

        min_age =
          opts
          |> Keyword.get(:min_age, 0)
          |> System.convert_time_unit(:seconds, :native)

        max_age =
          opts
          |> Keyword.get(:max_age, now)
          |> System.convert_time_unit(:seconds, :native)

        gen all gen_username <- username(),
                timestamp <- integer((now - max_age)..(now - min_age)),
                ip <- {byte(), byte(), byte(), byte()},
                useragent <- string(:ascii) do
          username = opts[:username] || gen_username

          login = %Login{
            username: username,
            serial: 48 |> :crypto.strong_rand_bytes() |> Base.encode64(),
            token: 48 |> :crypto.strong_rand_bytes() |> Base.encode64(),
            sid: 96 |> :crypto.strong_rand_bytes() |> Base.encode64(),
            created_at: timestamp,
            last_login: timestamp,
            last_ip: ip,
            last_useragent: useragent
          }

          login
        end
      end

      defp clear_store_and_put_logins(logins) do
        clear_store()
        put_logins(logins)
      end

      defp clear_store do
        :ets.delete_all_objects(@ets_table)
        MemoryStore.clear(@server)
      end

      defp put_logins(%Login{} = login), do: put_login(login)
      defp put_logins(logins), do: Enum.each(logins, &put_login/1)

      defp put_login(%Login{username: username, sid: sid} = login) do
        SessionStore.put(nil, sid, %{username: username}, @ets_table)
        MemoryStore.put(login, @server)
      end
    end
  end
end
