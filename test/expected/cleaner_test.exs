defmodule Expected.CleanerTest do
  use Expected.Case

  alias Expected.Cleaner
  alias Expected.ConfigurationError

  @three_months 7_776_000

  describe "start_link/1" do
    test "starts the GenServer" do
      assert {:ok, pid} = Cleaner.start_link()
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "raises an exception if the timeout is invalid" do
      Application.put_env(:expected, :cleaner_period, 0)

      assert_raise ConfigurationError,
                   ConfigurationError.message(%{reason: :bad_cleaner_timeout}),
                   fn -> Cleaner.start_link() end
    end
  end

  describe "the cleaner GenServer" do
    setup [:setup_stores]

    property "triggers login cleaning after timeout" do
      check all recent_logins <-
                  uniq_list_of(login(max_age: @three_months), length: 5),
                old_logins <-
                  uniq_list_of(
                    login(min_age: @three_months),
                    length: 5
                  ),
                max_runs: 1 do
        clear_store_and_put_logins(recent_logins ++ old_logins)

        Application.put_env(:expected, :cleaner_period, 1)
        assert {:ok, _} = start_supervised(Cleaner)

        # Wait for the cleaning to trigger.
        Process.sleep(1100)
        stop_supervised(Cleaner)

        Enum.each(recent_logins, fn %{username: username, serial: serial} ->
          assert {:ok, %Login{}} = MemoryStore.get(username, serial, @server)
        end)

        Enum.each(old_logins, fn %{username: username, serial: serial} ->
          assert {:error, :no_login} =
                   MemoryStore.get(username, serial, @server)
        end)
      end
    end

    property "does not trigger login cleaning before cleaner period is over" do
      check all recent_logins <-
                  uniq_list_of(login(max_age: @one_year), length: 5),
                old_logins <-
                  uniq_list_of(
                    login(min_age: @one_year),
                    length: 5
                  ),
                max_runs: 10 do
        clear_store_and_put_logins(recent_logins ++ old_logins)

        Application.put_env(:expected, :cleaner_period, 1)
        assert {:ok, _} = start_supervised(Cleaner)

        # Wait a millisecond to let the cleaner start.
        Process.sleep(1)
        stop_supervised(Cleaner)

        Enum.each(recent_logins ++ old_logins, fn %{
                                                    username: username,
                                                    serial: serial
                                                  } ->
          assert {:ok, %Login{}} = MemoryStore.get(username, serial, @server)
        end)
      end
    end

    property "use three months as the default cookie_max_age" do
      check all recent_logins <-
                  uniq_list_of(login(max_age: @three_months), length: 5),
                old_logins <-
                  uniq_list_of(
                    login(min_age: @three_months),
                    length: 5
                  ),
                max_runs: 10 do
        clear_store_and_put_logins(recent_logins ++ old_logins)

        # Set the cleaner timeout to 1ms (test mode).
        Application.put_env(:expected, :cleaner_period, :test)
        assert {:ok, _} = start_supervised(Cleaner)

        # Wait a bit to let the cleaner do its work.
        Process.sleep(2)
        stop_supervised(Cleaner)

        Enum.each(recent_logins, fn %{username: username, serial: serial} ->
          assert {:ok, %Login{}} = MemoryStore.get(username, serial, @server)
        end)

        Enum.each(old_logins, fn %{username: username, serial: serial} ->
          assert {:error, :no_login} =
                   MemoryStore.get(username, serial, @server)
        end)
      end
    end

    property "fetches the cookie_max_age from the application configuration" do
      check all max_age <- integer(1..@one_year),
                recent_logins <-
                  uniq_list_of(login(max_age: max_age), length: 5),
                old_logins <-
                  uniq_list_of(
                    login(min_age: max_age),
                    length: 5
                  ),
                max_runs: 10 do
        clear_store_and_put_logins(recent_logins ++ old_logins)

        # Set the cleaner timeout to 1ms (test mode).
        Application.put_env(:expected, :cleaner_period, :test)
        Application.put_env(:expected, :cookie_max_age, max_age)
        assert {:ok, _} = start_supervised(Cleaner)

        # Wait a bit to let the cleaner do its work.
        Process.sleep(2)
        stop_supervised(Cleaner)

        Enum.each(recent_logins, fn %{username: username, serial: serial} ->
          assert {:ok, %Login{}} = MemoryStore.get(username, serial, @server)
        end)

        Enum.each(old_logins, fn %{username: username, serial: serial} ->
          assert {:error, :no_login} =
                   MemoryStore.get(username, serial, @server)
        end)
      end
    end
  end
end
