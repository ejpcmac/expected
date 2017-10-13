defmodule Expected.Store do
  @moduledoc """
  Specification for login store.
  """

  alias Expected.Login

  @doc """
  Initialises the store.

  The value returned from this callback is passed as the last argument to
  `list_user_logins/2`, `get/3`, `put/2` and `delete/3`.
  """
  @callback init(opts :: term) :: term

  @doc """
  Lists the logins present in the store for the given `username`.
  """
  @callback list_user_logins(username :: String.t, opts :: term) :: [Login.t]

  @doc """
  Gets the login for the given `username` and `serial` from the store.
  """
  @callback get(username :: String.t, serial :: String.t, opts :: term) ::
    {:ok, Login.t} |
    {:error, :no_login}

  @doc """
  Puts a login in the store.

  This callback must:

    * create a new entry if there is none for the `username` **and** `serial`,
    * replace the entry if there is already one for the `username` **and**
      `serial`.

  In other words, the couple `{username, serial}` must be unique.
  """
  @callback put(login :: Login.t, opts :: term) :: :ok

  @doc """
  Deletes a login from the store given its `username` and `serial`.
  """
  @callback delete(username :: String.t, serial :: String.t, opts :: term) ::
    :ok
end
