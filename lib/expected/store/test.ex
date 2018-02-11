defmodule Expected.Store.Test do
  @moduledoc """
  A module for testing `Expected.Store` implementations.

  ## Usage

  First, add [`stream_data`](https://github.com/whatyouhide/stream_data) to your
  dependencies:

      {:stream_data, "~> 0.4.0", only: :test}

  It is needed because this module uses property-testing.

  Then, create a test module for you store using `Expected.Store.Test` and
  defining the `init_store/1` and `clear_store/1` helpers:

      defmodule MyExpected.StoreTest do
        use ExUnit.Case
        use Expected.Store.Test, store: MyExpected.Store

        # Define an init_store/1 setup function.
        defp init_store(_) do
          # Initialise your store if needed.

          # Return a map containing your options as `opts`.
          %{opts: init(table: :expected)}
        end

        # Define a clear_store/1 helper:
        defp clear_store(opts), do: something_that_clears_your_store(opts)

        # Test your init function
        describe "init/1" do
          property "returns the table name" do
            check all table <- atom(:alphanumeric) do
              assert init(table: table) == table
            end
          end
        end
      end

  With this minimal code, the behaviours of the implementations for
  `c:Expected.Store.list_user_logins/2`, `c:Expected.Store.get/3`,
  `c:Expected.Store.put/2`, `c:Expected.Store.delete/3` and
  `c:Expected.Store.clean_old_logins/2` are automatically tested.
  """

  defmacro __using__(opts) do
    store = Keyword.fetch!(opts, :store)

    # credo:disable-for-next-line Credo.Check.Refactor.LongQuoteBlocks
    quote do
      use ExUnitProperties

      import unquote(store)

      alias Expected.Login

      @one_year 31_536_000

      # Username generator
      defp username, do: string(:ascii, min_length: 3)

      # Login generator
      defp gen_login(opts \\ []) do
        now = System.os_time()

        min_age =
          opts
          |> Keyword.get(:min_age, 0)
          |> System.convert_time_unit(:seconds, :native)

        max_age =
          opts
          |> Keyword.get(:max_age, now)
          |> System.convert_time_unit(:seconds, :native)

        gen all gen_username <- username(),
                timestamp <- integer((now - max_age)..(now - min_age)),
                ip <- {byte(), byte(), byte(), byte()},
                useragent <- string(:ascii) do
          username = opts[:username] || gen_username

          login = %Login{
            username: username,
            serial: 48 |> :crypto.strong_rand_bytes() |> Base.encode64(),
            token: 48 |> :crypto.strong_rand_bytes() |> Base.encode64(),
            sid: 96 |> :crypto.strong_rand_bytes() |> Base.encode64(),
            created_at: timestamp,
            last_login: timestamp,
            last_ip: ip,
            last_useragent: useragent
          }

          login
        end
      end

      defp clear_store_and_put_logins(logins, opts) do
        clear_store(opts)
        put_logins(logins, opts)
      end

      defp put_logins(%Login{} = login, opts), do: put(login, opts)
      defp put_logins(logins, opts), do: Enum.each(logins, &put(&1, opts))

      describe "list_user_logins/2" do
        setup [:init_store]

        property "lists the logins present in the store for a user", %{
          opts: opts
        } do
          check all user <- username(),
                    length <- integer(1..5),
                    user_logins <-
                      uniq_list_of(gen_login(username: user), length: length),
                    other_logins <- uniq_list_of(gen_login(), length: 5) do
            clear_store_and_put_logins(user_logins ++ other_logins, opts)

            logins = list_user_logins(user, opts)

            assert length(logins) == length

            Enum.each(user_logins, fn login ->
              assert login in logins
            end)
          end
        end

        property "works as well when the user is not present in the store", %{
          opts: opts
        } do
          check all user <- username() do
            assert list_user_logins(user, opts) == []
          end
        end
      end

      describe "get/3" do
        setup [:init_store]

        property "gets the login for the given username and serial", %{
          opts: opts
        } do
          check all login <- gen_login() do
            clear_store_and_put_logins(login, opts)
            assert get(login.username, login.serial, opts) == {:ok, login}
          end
        end

        property "returns an error if there is no correspondant login", %{
          opts: opts
        } do
          check all login <- gen_login(),
                    other_user <- username() do
            clear_store_and_put_logins(login, opts)
            bad_serial = 48 |> :crypto.strong_rand_bytes() |> Base.encode64()

            assert get(login.username, bad_serial, opts) == {:error, :no_login}
            assert get(other_user, bad_serial, opts) == {:error, :no_login}
          end
        end
      end

      describe "put/2" do
        setup [:init_store]

        property "creates a new entry if there is none for the given username",
                 %{opts: opts} do
          check all login <- gen_login() do
            clear_store(opts)

            assert list_user_logins(login.username, opts) == []
            assert put(login, opts) == :ok
            assert list_user_logins(login.username, opts) == [login]
          end
        end

        property "creates a new entry if there is none for the given serial", %{
          opts: opts
        } do
          check all %{username: username} = login1 <- gen_login(),
                    login2 <- gen_login(username: username) do
            clear_store_and_put_logins(login1, opts)

            assert list_user_logins(username, opts) == [login1]

            assert put(login2, opts) == :ok

            user_logins = list_user_logins(username, opts)
            assert login1 in user_logins
            assert login2 in user_logins
          end
        end

        property "replaces an existing entry if there is one already", %{
          opts: opts
        } do
          check all login <- gen_login() do
            clear_store_and_put_logins(login, opts)
            new_token = 48 |> :crypto.strong_rand_bytes() |> Base.encode64()
            updated_login = %{login | token: new_token}

            assert list_user_logins(login.username, opts) == [login]
            assert put(updated_login, opts) == :ok
            assert list_user_logins(login.username, opts) == [updated_login]
          end
        end
      end

      describe "delete/3" do
        setup [:init_store]

        property "deletes a login given its username and serial", %{
          opts: opts
        } do
          check all login <- gen_login() do
            clear_store_and_put_logins(login, opts)

            assert list_user_logins(login.username, opts) == [login]
            assert delete(login.username, login.serial, opts) == :ok
            assert list_user_logins(login.username, opts) == []
          end
        end

        property "works as well if there is no corresponding login", %{
          opts: opts
        } do
          check all login <- gen_login() do
            clear_store_and_put_logins(login, opts)
            assert delete(login.username, login.serial, opts) == :ok
          end
        end
      end

      describe "clean_old_logins/2" do
        setup [:init_store]

        property "deletes old logins from the store", %{opts: opts} do
          check all max_age <- integer(1..@one_year),
                    recent_logins <-
                      uniq_list_of(gen_login(max_age: max_age), length: 5),
                    old_logins <-
                      uniq_list_of(gen_login(min_age: max_age), length: 5) do
            clear_store_and_put_logins(recent_logins ++ old_logins, opts)

            clean_old_logins(max_age, opts)

            Enum.each(recent_logins, fn %{username: username, serial: serial} ->
              assert {:ok, %Login{}} = get(username, serial, opts)
            end)

            Enum.each(old_logins, fn %{username: username, serial: serial} ->
              assert get(username, serial, opts) == {:error, :no_login}
            end)
          end
        end

        property "returns the list of deleted logins", %{opts: opts} do
          check all max_age <- integer(1..@one_year),
                    recent_logins <-
                      uniq_list_of(gen_login(max_age: max_age), length: 5),
                    old_logins <-
                      uniq_list_of(gen_login(min_age: max_age), length: 5) do
            clear_store_and_put_logins(recent_logins ++ old_logins, opts)

            deleted_logins = clean_old_logins(max_age, opts)

            assert length(deleted_logins) == 5

            Enum.each(old_logins, fn login ->
              assert login in deleted_logins
            end)
          end
        end
      end
    end
  end
end
