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
          table: :expected,
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

  def message(%{reason: :no_session_store}) do
    """
    Session store not set.

    You must set a session store in the configuration:

        config :expected,
          store: :mnesia,
          table: :expected,
          session_store: PlugSessionMnesia.Store,
          session_cookie: "_my_app_key",
          session_opts: [table: :session]
    """
  end

  def message(%{reason: :no_session_cookie}) do
    """
    Session cookie key not set.

    You must set a session cookie name in the configuration:

        config :expected,
          store: :mnesia,
          table: :expected,
          session_store: PlugSessionMnesia.Store,
          session_cookie: "_my_app_key",
          session_opts: [table: :session]
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

defmodule Expected.SessionError do
  @moduledoc """
  Error raised by `Expected.Plugs.register_login/2` if the session cookie is not
  present.
  """

  defexception []

  def message(_) do
    session_cookie = Application.fetch_env!(:expected, :session_cookie)

    """
    The connection does not contain a cookie named \"#{session_cookie}\".

    This problem can occur if the session has not been fetched.
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
