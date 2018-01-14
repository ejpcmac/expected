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
  `Expected`) or create it yourself. In the latter case, you **must** ensure
  that:

    * the table is a `:bag`,
    * it stores `Expected.MnesiaStore.LoginRecord`, *i.e.* the `record_name` is
      set to `:login` and the attributes are the `Expected.Login` keys,
    * `:serial` and `:last_login` must be indexed.

  For instance:

      :mnesia.start()
      :mnesia.create_table(
        :logins,
        type: :bag,
        record_name: :login,
        attributes: Expected.Login.keys(),
        index: [:serial, :last_login],
        disc_copies: [node()]
      )

  For Mnesia to work properly, you need to add it to your extra applications:

      def application do
        [
          mod: {MyApp.Application, []},
          extra_applications: [:logger, :mnesia]
        ]
      end
  """

  @behaviour Expected.Store

  import __MODULE__.LoginRecord

  alias __MODULE__.LoginRecord
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
      :mnesia.read(table, username)
    end

    case :mnesia.transaction(t) do
      {:atomic, user_logins} ->
        Enum.map(user_logins, &to_struct(&1))

      {:aborted, {:no_exists, _}} ->
        raise MnesiaStoreError, reason: :table_not_exists
    end
  end

  @impl true
  def get(username, serial, table) do
    t = fn ->
      do_get(username, serial, table)
    end

    case :mnesia.transaction(t) do
      {:atomic, [login]} ->
        {:ok, to_struct(login)}

      {:atomic, []} ->
        {:error, :no_login}

      {:aborted, {:no_exists, _}} ->
        raise MnesiaStoreError, reason: :table_not_exists
    end
  end

  @impl true
  def put(%Login{username: username, serial: serial} = login, table) do
    t = fn ->
      do_delete(username, serial, table)
      :mnesia.write(table, from_struct(login), :write)
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
      do_delete(username, serial, table)
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
            login(last_login: :"$1"),
            [{:<, :"$1", oldest_timestamp}],
            [:"$_"]
          }
        ])

      for login <- old_logins do
        :mnesia.delete_object(table, login, :write)
        to_struct(login)
      end
    end

    case :mnesia.transaction(t) do
      {:atomic, deleted_logins} ->
        deleted_logins

      {:aborted, {:no_exists, _}} ->
        raise MnesiaStoreError, reason: :table_not_exists
    end
  end

  @spec do_get(String.t(), String.t(), atom()) :: [LoginRecord.t()]
  defp do_get(username, serial, table) do
    :mnesia.index_match_object(
      table,
      login(username: username, serial: serial),
      1 + login(:serial),
      :read
    )
  end

  @spec do_delete(String.t(), String.t(), atom()) :: :ok
  defp do_delete(username, serial, table) do
    case do_get(username, serial, table) do
      [login] -> :mnesia.delete_object(table, login, :write)
      [] -> :ok
    end
  end
end
