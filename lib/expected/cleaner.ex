defmodule Expected.Cleaner do
  @moduledoc """
  A module to automate old logins cleaning.
  """

  use GenServer

  @cookie_max_age 7_776_000

  @doc """
  Starts the login cleaner.
  """
  @spec start_link :: GenServer.on_start()
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_args \\ nil) do
    timeout = Application.get_env(:expected, :cleaner_period, 86_400)
    max_age = Application.get_env(:expected, :cookie_max_age, @cookie_max_age)
    GenServer.start_link(__MODULE__, {timeout * 1000, max_age})
  end

  @impl true
  def init({timeout, _max_age} = args) do
    schedule_work(timeout)
    {:ok, args}
  end

  @impl true
  def handle_info(:work, {timeout, max_age} = args) do
    schedule_work(timeout)
    :ok = Expected.clean_old_logins(max_age)
    {:noreply, args}
  end

  @spec schedule_work(non_neg_integer()) :: reference()
  defp schedule_work(timeout) do
    Process.send_after(self(), :work, timeout)
  end
end
