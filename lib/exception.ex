## This file defines exceptions for Expected.

defmodule Expected.ConfigurationError do
  @moduledoc """
  Error raised when the configuration is invalid or incomplete.
  """

  defexception [:reason]

  def message(%{reason: :no_store}) do
    """
    Login store not configured.

    You must set a login store in the configuration:

        config :expected,
          store: :mnesia,
          table: :logins,
          ...
    """
  end

  def message(%{reason: :no_process_name}) do
    """
    Process name not configured for the `:memory` store.

    You must set a process name for the `:memory` store in the configuration:

        config :expected,
          store: :memory,
          process_name: :test_store,
          ...
    """
  end

  def message(%{reason: :no_mnesia_table}) do
    """
    Table not configured for the `:mnesia` store.

    You must set a table for the `:mnesia` store in the configuration:

        config :expected,
          store: :mnesia,
          table: :logins,
          ...
    """
  end

  def message(%{reason: :no_auth_cookie}) do
    """
    Authentication cookie key not set.

    You must set an authentication cookie name in the configuration:

        config :expected,
          store: :mnesia,
          table: :logins,
          auth_cookie: "_my_app_auth",  # Set your authentication cookie here.
          session_store: PlugSessionMnesia.Store,
          session_cookie: "_my_app_key"
    """
  end

  def message(%{reason: :no_session_store}) do
    """
    Session store not set.

    You must set a session store in the configuration:

        config :expected,
          store: :mnesia,
          table: :logins,
          auth_cookie: "_my_app_auth",
          session_store: PlugSessionMnesia.Store,  # Set your session store.
          session_cookie: "_my_app_key"
    """
  end

  def message(%{reason: :no_session_cookie}) do
    """
    Session cookie key not set.

    You must set a session cookie name in the configuration:

        config :expected,
          store: :mnesia,
          table: :logins,
          auth_cookie: "_my_app_auth",
          session_store: PlugSessionMnesia.Store,
          session_cookie: "_my_app_key"  # Set your session cookie here.
    """
  end
end

defmodule Expected.PlugError do
  @moduledoc """
  Error raised by `Expected.Plugs` functions if `Expected` has not been plugged.
  """

  defexception []

  def message(_) do
    """
    `Expected` has not been plugged.

    Please ensure to plug `Expected` in your endpoint:

        plug Expected
    """
  end
end

defmodule Expected.CurrentUserError do
  @moduledoc """
  Error raised by `Expected.Plugs.register_login/2` if there is no currently
  logged-in user.
  """

  defexception []

  def message(_) do
    """
    There is no currently logged-in user.

    Please ensure the session contains a `:current_user` key:

        conn
        |> put_session(:current_user, %User{username: "user", name: "A User"})
        |> register_login()

    Alternatively, you can precise which field to use:

        conn
        |> put_session(:logged_in_user, %User{username: "user", name: "A User"})
        |> register_login(current_user: :logged_in_user)
    """
  end
end

defmodule Expected.InvalidUserError do
  @moduledoc """
  Error raised by `Expected.Plugs.register_login/2` if the `current_user` does
  not contain a valid user.
  """

  defexception [:current_user]

  def message(attrs) do
    current_user = ":" <> Atom.to_string(attrs.current_user || :current_user)

    """
    The `#{current_user}` does not contains a `username` field.

    Please ensure the `#{current_user}` session key contains a `username`
    field:

        conn
        |> put_session(#{current_user}, %User{username: "user"})
        |> register_login()

    Alternatively, you can use another field and precise it as an option:

        conn
        |> put_session(#{current_user}, %User{user_id: "user"})
        |> register_login(username: :user_id)
    """
  end
end

defmodule Expected.MnesiaStoreError do
  @moduledoc """
  Error raised by the `:mnesia` store when there is a problem.
  """

  defexception [:reason]

  def message(%{reason: :table_not_exists}) do
    """
    The Mnesia table given to the login store does not exist.

    Please ensure the table has been created. You can ask mix to create it for
    you:

        mix expected.mnesia.setup
    """
  end

  def message(%{reason: :invalid_table_format}) do
    """
    The Mnesia table given to the login store has not the correct format.

    Please ensure it has the following format:

        {
          user_serial :: String.t(),
          username :: String.t(),
          login :: Expected.Login.t(),
          last_login :: integer()
        }
    """
  end
end

defmodule Expected.MnesiaTableExistsError do
  @moduledoc """
  Error raised by `Expected.MnesiaStore.Helpers.setup!/0` if a table already
  exists and has different attributes.
  """

  defexception [:table]

  def message(attrs) do
    "The table #{attrs.table} already exists. Please choose another name."
  end
end
