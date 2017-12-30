defmodule Expected.MemoryStore.Server do
  @moduledoc """
  GenServer for maintaining the state in `Expected.MemoryStore`.
  """

  use GenServer

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:list_user_logins, username}, _from, state) do
    logins =
      state
      |> Map.get(username, %{})
      |> Map.values()

    {:reply, logins, state}
  end

  @impl true
  def handle_call({:get, username, serial}, _from, state) do
    result =
      case state do
        %{^username => %{^serial => login}} -> {:ok, login}
        _ -> {:error, :no_login}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:put, login}, _from, state) do
    {_, state} =
      Map.get_and_update(state, login.username, fn user_logins ->
        {user_logins, Map.put(user_logins || %{}, login.serial, login)}
      end)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete, username, serial}, _from, state) do
    user_logins =
      state
      |> Map.get(username, %{})
      |> Map.delete(serial)

    state =
      if Enum.empty?(user_logins),
        do: Map.delete(state, username),
        else: Map.put(state, username, user_logins)

    {:reply, :ok, state}
  end
end
