defmodule Expected.Store do
  @moduledoc """
  Specification for login stores.

  To automatically generate tests for a new store, you can use
  `Expected.Store.Test`.
  """

  alias Expected.Login

  @doc """
  Initialises the store.

  The value returned from this callback is passed as the last argument to
  `c:list_user_logins/2`, `c:get/3`, `c:put/2` and `c:delete/3`.
  """
  @callback init(opts :: keyword()) :: term()

  @doc """
  Lists the logins present in the store for the given `username`.
  """
  @callback list_user_logins(username :: String.t(), opts :: term()) :: [
              Login.t()
            ]

  @doc """
  Gets the login for the given `username` and `serial` from the store.
  """
  @callback get(username :: String.t(), serial :: String.t(), opts :: term()) ::
              {:ok, Login.t()}
              | {:error, :no_login}

  @doc """
  Puts a login in the store.

  This callback must:

    * create a new entry if there is none for the `username` **and** `serial`,
    * replace the entry if there is already one for the `username` **and**
      `serial`.

  In other words, the couple `{username, serial}` must be unique.
  """
  @callback put(login :: Login.t(), opts :: term()) :: :ok

  @doc """
  Deletes a login from the store given its `username` and `serial`.
  """
  @callback delete(
              username :: String.t(),
              serial :: String.t(),
              opts :: term()
            ) :: :ok

  @doc """
  Cleans all the logins that have not been used for more than `max_age`.

  This callback must compare with the `:last_login` field, not `:created_at`.
  """
  @callback clean_old_logins(max_age :: integer(), opts :: term()) :: [
              Login.t()
            ]
end
