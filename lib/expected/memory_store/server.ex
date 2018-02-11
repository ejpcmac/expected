defmodule Expected.MemoryStore.Server do
  @moduledoc """
  GenServer for maintaining the state in `Expected.MemoryStore`.
  """

  use GenServer

  alias Expected.Login

  @impl true
  def init(:ok) do
    {:ok, %{}}
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

  @impl true
  def handle_call({:clean_old_logins, max_age}, _from, state) do
    native_max_age = System.convert_time_unit(max_age, :seconds, :native)
    oldest_timestamp = System.os_time() - native_max_age

    {state, deleted_logins} = clean_old_logins(state, oldest_timestamp)

    {:reply, deleted_logins, state}
  end

  @impl true
  def handle_call(:clear, _from, _state) do
    {:reply, :ok, %{}}
  end

  @spec clean_old_logins(map(), integer()) :: {map(), [Login.t()]}
  defp clean_old_logins(logins, oldest_timestamp) do
    logins
    |> Enum.map_reduce([], fn {username, user_logins}, deleted_logins ->
      {keeped, deleted} = clean_old_user_logins(user_logins, oldest_timestamp)
      {{username, keeped}, deleted ++ deleted_logins}
    end)
    |> first_into_map()
  end

  @spec clean_old_user_logins(map(), integer()) :: {map(), [Login.t()]}
  defp clean_old_user_logins(user_logins, oldest_timestamp) do
    user_logins
    |> Enum.reduce({[], []}, fn {serial, login}, {keeped, deleted} ->
      if login.last_login >= oldest_timestamp,
        do: {[{serial, login} | keeped], deleted},
        else: {keeped, [login | deleted]}
    end)
    |> first_into_map()
  end

  @spec first_into_map({list(), list()}) :: {map(), list()}
  defp first_into_map({map, list}), do: {Enum.into(map, %{}), list}
end
