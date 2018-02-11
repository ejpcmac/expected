defmodule Expected.MemoryStore do
  @moduledoc """
  Stores login data in-memory.

  This store is mainly written for test purposes. It does not persist data on
  disk nor share it between nodes.

  To use this store, you must precise the process name in the application
  configuration:

      config :expected,
        store: :memory,
        process_name: :test_store,
        ...

  You also must start the server:

      Expected.MemoryStore.start_link()
  """

  @behaviour Expected.Store

  alias Expected.ConfigurationError

  @doc """
  Starts the store server.
  """
  @spec start_link :: GenServer.on_start()
  def start_link do
    case Application.fetch_env(:expected, :process_name) do
      {:ok, name} ->
        GenServer.start_link(__MODULE__.Server, :ok, name: name)

      :error ->
        raise ConfigurationError, reason: :no_process_name
    end
  end

  @impl true
  def init(opts) do
    case Keyword.fetch(opts, :process_name) do
      {:ok, server} -> server
      :error -> raise ConfigurationError, reason: :no_process_name
    end
  end

  @impl true
  def list_user_logins(username, server) do
    GenServer.call(server, {:list_user_logins, username})
  end

  @impl true
  def get(username, serial, server) do
    GenServer.call(server, {:get, username, serial})
  end

  @impl true
  def put(login, server) do
    GenServer.call(server, {:put, login})
  end

  @impl true
  def delete(username, serial, server) do
    GenServer.call(server, {:delete, username, serial})
  end

  @impl true
  def clean_old_logins(max_age, server) do
    GenServer.call(server, {:clean_old_logins, max_age})
  end

  @doc """
  Clears all logins from the memory store.
  """
  @spec clear(pid()) :: :ok
  def clear(server) do
    GenServer.call(server, :clear)
  end

  @doc false
  @spec child_spec(term()) :: Supervisor.child_spec()
  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    }
  end
end
