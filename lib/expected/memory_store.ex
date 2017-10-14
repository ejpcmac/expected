defmodule Expected.MemoryStore do
  @moduledoc """
  Stores login data in-memory.

  This store is mainly written for test purposes. It does not persist data on
  disk nor share it between nodes.

  It is possible to initialise it with a defined state to help testing:

      Expected.MemoryStore.init(default: %{})
  """

  @behaviour Expected.Store

  @impl true
  def init(opts) do
    default = Keyword.get(opts, :default, %{})
    {:ok, pid} = GenServer.start_link(__MODULE__.Server, default)
    pid
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
end
