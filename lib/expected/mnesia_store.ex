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
        username :: String.t(),
        logins :: %{required(String.t()) => Expected.Login.t()}
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
    case lookup_user_logins!(username, table) do
      [{^table, ^username, %{} = user_logins}] -> Map.values(user_logins)
      [] -> []
    end
  end

  @impl true
  def get(username, serial, table) do
    case lookup_user_logins!(username, table) do
      [{^table, ^username, %{^serial => login}}] -> {:ok, login}
      _ -> {:error, :no_login}
    end
  end

  @impl true
  def put(%Login{username: username, serial: serial} = login, table) do
    case lookup_user_logins!(username, table) do
      [{^table, ^username, %{} = user_logins}] ->
        user_logins
        |> Map.put(serial, login)
        |> put_user_logins!(username, table)

      [] ->
        put_user_logins!(%{serial => login}, username, table)
    end
  end

  @impl true
  def delete(username, serial, table) do
    case lookup_user_logins!(username, table) do
      [{^table, ^username, %{} = user_logins}] ->
        user_logins
        |> Map.delete(serial)
        |> put_user_logins!(username, table)

      [] ->
        :ok
    end
  end

  @spec lookup_user_logins!(String.t(), atom()) :: [{atom(), String.t(), map}]
  defp lookup_user_logins!(username, table) do
    t = fn ->
      :mnesia.read({table, username})
    end

    case :mnesia.transaction(t) do
      {:atomic, user_logins} ->
        user_logins

      {:aborted, {:no_exists, _}} ->
        raise MnesiaStoreError, reason: :table_not_exists
    end
  end

  @spec put_user_logins!(map(), String.t(), atom()) :: :ok
  defp put_user_logins!(user_logins, username, table) do
    t =
      if Enum.empty?(user_logins),
        do: fn -> :mnesia.delete({table, username}) end,
        else: fn -> :mnesia.write({table, username, user_logins}) end

    case :mnesia.transaction(t) do
      {:atomic, _} ->
        :ok

      {:aborted, {:no_exists, _}} ->
        raise MnesiaStoreError, reason: :table_not_exists

      {:aborted, {:bad_type, _}} ->
        raise MnesiaStoreError, reason: :invalid_table_format
    end
  end
end
