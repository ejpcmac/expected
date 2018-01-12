defmodule Expected.CleanerTest do
  use Expected.Case

  alias Expected.Cleaner

  defp with_logins(_) do
    setup_stores()

    :ok = MemoryStore.put(@login, @server)
    :ok = MemoryStore.put(@old_login, @server)
  end

  describe "start_link/1" do
    test "starts the GenServer" do
      assert {:ok, _} = Cleaner.start_link()
    end
  end

  describe "the cleaner GenServer" do
    setup [:with_logins]

    test "triggers login cleaning after timeout" do
      Application.put_env(:expected, :cleaner_period, 1)

      assert {:ok, _} = Cleaner.start_link()

      # Wait for the cleaning to trigger.
      Process.sleep(1100)

      assert MemoryStore.list_user_logins("user", @server) == [@login]
    end

    test "does not trigger login cleaning before timeout" do
      Application.put_env(:expected, :cleaner_period, 1)

      assert {:ok, _} = Cleaner.start_link()

      # Wait a millisecond to let the cleaner start.
      Process.sleep(1)

      assert MemoryStore.list_user_logins("user", @server) == [
               @login,
               @old_login
             ]
    end

    test "use three months as the default cookie_max_age" do
      less_than_three_months_ago =
        @now - System.convert_time_unit(@three_months - 60, :seconds, :native)

      more_than_three_months_ago =
        @now - System.convert_time_unit(@three_months + 60, :seconds, :native)

      login_not_to_delete = %{
        @login
        | username: "cleaner_test_user",
          serial: "serial2",
          last_login: less_than_three_months_ago
      }

      login_to_delete = %{
        @login
        | username: "cleaner_test_user",
          serial: "serial3",
          last_login: more_than_three_months_ago
      }

      :ok = MemoryStore.put(login_not_to_delete, @server)
      :ok = MemoryStore.put(login_to_delete, @server)

      # Start the cleaner immediately.
      Application.put_env(:expected, :cleaner_period, 0)
      assert {:ok, _} = Cleaner.start_link()

      # Wait a millisecond to let the cleaner start.
      Process.sleep(1)

      assert MemoryStore.list_user_logins("cleaner_test_user", @server) == [
               login_not_to_delete
             ]
    end

    test "fetches the cookie_max_age from the application configuration" do
      Application.put_env(:expected, :cookie_max_age, 86_400)

      less_than_a_day_ago =
        @now - System.convert_time_unit(86_400 - 60, :seconds, :native)

      more_than_a_day_ago =
        @now - System.convert_time_unit(86_400 + 60, :seconds, :native)

      login_not_to_delete = %{
        @login
        | username: "cleaner_test_user",
          serial: "serial2",
          last_login: less_than_a_day_ago
      }

      login_to_delete = %{
        @login
        | username: "cleaner_test_user",
          serial: "serial3",
          last_login: more_than_a_day_ago
      }

      :ok = MemoryStore.put(login_not_to_delete, @server)
      :ok = MemoryStore.put(login_to_delete, @server)

      # Start the cleaner immediately.
      Application.put_env(:expected, :cleaner_period, 0)
      assert {:ok, _} = Cleaner.start_link()

      # Wait a millisecond to let the cleaner start.
      Process.sleep(1)

      assert MemoryStore.list_user_logins("cleaner_test_user", @server) == [
               login_not_to_delete
             ]
    end
  end
end
