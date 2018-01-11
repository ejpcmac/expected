defmodule Expected.MnesiaStore do
  @moduledoc """
  Stores login data in a Mnesia table.

  To use this store, configure `:expected` accordingly and set the table name in
  the application configuration:

      config :expected,
        store: :mnesia,
        table: :logins,
        ...

  This table is not created by the store. You can use helpers to create it (see
  `Expected`) or create it yourself.

  For Mnesia to work properly, you need to add it to your extra applications:

      def application do
        [
          mod: {MyApp.Application, []},
          extra_applications: [:logger, :mnesia]
        ]
      end

  ## Storage

  Stored entries use the following format:

      {
        user_serial :: String.t(),
        username :: String.t(),
        login :: Expected.Login.t(),
        last_login :: integer()
      }
  """

  @behaviour Expected.Store

  alias Expected.Login
  alias Expected.ConfigurationError
  alias Expected.MnesiaStoreError

  @impl true
  def init(opts) do
    case Keyword.fetch(opts, :table) do
      {:ok, table} -> table
      :error -> raise ConfigurationError, reason: :no_mnesia_table
    end
  end

  @impl true
  def list_user_logins(username, table) do
    t = fn ->
      :mnesia.match_object({table, :_, username, :_, :_})
    end

    case :mnesia.transaction(t) do
      {:atomic, user_logins} ->
        Enum.map(user_logins, fn {_, _, _, login, _} -> login end)

      {:aborted, {:no_exists, _}} ->
        raise MnesiaStoreError, reason: :table_not_exists
    end
  end

  @impl true
  def get(username, serial, table) do
    t = fn ->
      :mnesia.read({table, "#{username}.#{serial}"})
    end

    case :mnesia.transaction(t) do
      {:atomic, [{_, _, _, login, _}]} ->
        {:ok, login}

      {:atomic, []} ->
        {:error, :no_login}

      {:aborted, {:no_exists, _}} ->
        raise MnesiaStoreError, reason: :table_not_exists
    end
  end

  @impl true
  def put(
        %Login{username: username, serial: serial, last_login: last_login} =
          login,
        table
      ) do
    user_serial = "#{username}.#{serial}"

    t = fn ->
      :mnesia.write({table, user_serial, username, login, last_login})
    end

    case :mnesia.transaction(t) do
      {:atomic, _} ->
        :ok

      {:aborted, {:no_exists, _}} ->
        raise MnesiaStoreError, reason: :table_not_exists

      {:aborted, {:bad_type, _}} ->
        raise MnesiaStoreError, reason: :invalid_table_format
    end
  end

  @impl true
  def delete(username, serial, table) do
    t = fn ->
      :mnesia.delete({table, "#{username}.#{serial}"})
    end

    case :mnesia.transaction(t) do
      {:atomic, _} ->
        :ok

      {:aborted, {:no_exists, _}} ->
        raise MnesiaStoreError, reason: :table_not_exists
    end
  end

  @impl true
  def clean_old_logins(max_age, table) do
    native_max_age = System.convert_time_unit(max_age, :seconds, :native)
    oldest_timestamp = System.os_time() - native_max_age

    t = fn ->
      old_logins =
        :mnesia.select(table, [
          {
            {table, :"$1", :_, :"$3", :"$4"},
            [{:<, :"$4", oldest_timestamp}],
            [{{:"$1", :"$3"}}]
          }
        ])

      for {user_serial, login} <- old_logins do
        :mnesia.delete({table, user_serial})
        login
      end
    end

    case :mnesia.transaction(t) do
      {:atomic, deleted_logins} ->
        deleted_logins

      {:aborted, {:no_exists, _}} ->
        raise MnesiaStoreError, reason: :table_not_exists
    end
  end
end
