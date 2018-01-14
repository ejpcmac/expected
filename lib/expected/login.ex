defmodule Expected.Login do
  @moduledoc """
  A struct defining login information.

  ## Fields

    * `username` - the login username
    * `serial` - the login serial (*i.e.* a kind of persistent session ID for a
                 given machine)
    * `token` - the token for next authentication
    * `sid` - the current session ID
    * `created_at` - the initial login timestamp
    * `last_login` - the timestamp of last login using this serial
    * `last_ip` - the last IP used to login with this serial
    * `last_useragent` - the last user agent used to login
  """

  @fields quote(
            do: [
              username: String.t(),
              serial: String.t(),
              token: String.t(),
              sid: String.t(),
              created_at: integer(),
              last_login: integer(),
              last_ip: :inet.ip_address(),
              last_useragent: String.t()
            ]
          )

  @keys Keyword.keys(@fields)

  defstruct @keys

  @typedoc "A login"
  @type t() :: %__MODULE__{unquote_splicing(@fields)}

  @doc """
  Returns the login fields list.
  """
  @spec fields :: keyword()
  def fields, do: @fields

  @doc """
  Returns the login keys list.
  """
  @spec keys :: [atom()]
  def keys, do: @keys
end
