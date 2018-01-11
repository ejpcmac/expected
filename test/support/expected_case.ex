defmodule Expected.Case do
  @moduledoc """
  A test case for Expected.
  """

  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case
      use Plug.Test

      alias Expected.Login
      alias Expected.MemoryStore

      @server :test_store
      @auth_cookie "_test_auth"
      @session_cookie "_test_key"
      @ets_table :test_session

      @now System.os_time()
      @three_months 7_776_000
      @four_months System.convert_time_unit(10_368_000, :seconds, :native)
      @four_months_ago @now - @four_months

      @login %Login{
        username: "user",
        serial: "serial",
        token: "token",
        sid: "sid",
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

        on_exit fn ->
          Application.delete_env(:expected, :stores)
          Application.delete_env(:expected, :cookie_max_age)
        end
      end

      defp setup_stores do
        :ets.new(@ets_table, [:named_table, :public])
        MemoryStore.start_link()
      end
    end
  end
end
