defmodule Expected.Store.Test do
  @moduledoc """
  A module for testing `Expected.Store` implementations.

  In order to test a new `Expected.Store`, create a test module and use
  `Expected.Store.Test` by specifying the store to test:

      defmodule MyExpected.StoreTest do
        use ExUnit.Case
        use Expected.Store.Test, store: MyExpected.Store

        # Must be defined for Expected.Store.Test to work.
        defp init_store(_) do
          # Insert @login1 defined in Expected.Store.Test in your store.
          # ...

          # Return a map containing your options as `opts`.
          %{opts: init(table: :expected)}
        end

        # Test your init function
        describe "init/1" do
          test "returns the table name" do
            assert init(table: :expected) == :expected
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

    quote do
      import unquote(store)

      alias Expected.Login

      @now System.os_time()
      @three_months 7_776_000
      @four_months System.convert_time_unit(10_368_000, :seconds, :native)
      @four_months_ago @now - @four_months

      @login1 %Login{
        username: "user",
        serial: "1",
        token: "token",
        sid: "sid",
        created_at: @now,
        last_login: @now,
        last_ip: {127, 0, 0, 1},
        last_useragent: "ExUnit"
      }

      @login2 %{@login1 | serial: "2", token: "token2", sid: "sid2"}
      @login3 %{@login1 | username: "user2", token: "token3", sid: "sid3"}
      @old_login %{@login2 | last_login: @four_months_ago}

      @logins %{
        "user" => %{
          "1" => @login1
        }
      }

      describe "list_user_logins/2" do
        setup [:init_store]

        test "lists the logins present in the store for a user", %{
          opts: opts
        } do
          assert list_user_logins("user", opts) == [@login1]
        end

        test "works as well when the user is not present in the store", %{
          opts: opts
        } do
          assert list_user_logins("test", opts) == []
        end
      end

      describe "get/3" do
        setup [:init_store]

        test "gets the login for the given username and serial", %{
          opts: opts
        } do
          assert {:ok, @login1} = get("user", "1", opts)
        end

        test "returns an error if there is no correspondant login", %{
          opts: opts
        } do
          assert {:error, :no_login} = get("user", "9", opts)
          assert {:error, :no_login} = get("test", "1", opts)
        end
      end

      describe "put/2" do
        setup [:init_store]

        test "creates a new entry if there is none for the given serial", %{
          opts: opts
        } do
          assert :ok = put(@login2, opts)
          user_logins = list_user_logins("user", opts)

          assert @login1 in user_logins
          assert @login2 in user_logins
        end

        test "creates a new entry if there is none for the given username", %{
          opts: opts
        } do
          assert :ok = put(@login3, opts)
          assert list_user_logins("user2", opts) == [@login3]
        end

        test "replaces an existing entry if there is one already", %{
          opts: opts
        } do
          updated_login = %{@login1 | token: "new_token"}

          assert :ok = put(updated_login, opts)
          assert list_user_logins("user", opts) == [updated_login]
        end
      end

      describe "delete/3" do
        setup [:init_store]

        test "deletes a login given its username and serial", %{opts: opts} do
          assert :ok = delete("user", "1", opts)
          assert list_user_logins("user", opts) == []
        end

        test "works as well if there is no corresponding login", %{
          opts: opts
        } do
          assert :ok = delete("test", "1", opts)
        end
      end

      describe "clean_old_logins/2" do
        setup [:init_store]

        test "deletes old logins from the store", %{opts: opts} do
          :ok = put(@old_login, opts)
          clean_old_logins(@three_months, opts)

          assert {:ok, @login1} = get("user", "1", opts)
          assert {:error, :no_login} = get("user", "2", opts)
        end

        test "returns the list of deleted logins", %{opts: opts} do
          :ok = put(@old_login, opts)
          assert clean_old_logins(@three_months, opts) == [@old_login]
        end
      end
    end
  end
end
