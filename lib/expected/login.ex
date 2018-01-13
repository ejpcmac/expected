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

  defstruct [
    :username,
    :serial,
    :token,
    :sid,
    :created_at,
    :last_login,
    :last_ip,
    :last_useragent
  ]

  @typedoc "A login"
  @type t() :: %__MODULE__{
          username: String.t(),
          serial: String.t(),
          token: String.t(),
          sid: String.t() | nil,
          created_at: integer(),
          last_login: integer(),
          last_ip: :inet.ip_address(),
          last_useragent: String.t()
        }
end
