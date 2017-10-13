defmodule Expected.Login do
  @moduledoc """
  A struct defining login information.

  ## Fields

    * `username` - the login username
    * `serial` - the login serial (i.e. a kind of persistent session ID for a
                 given machine)
    * `token` - the token for next login
    * `sid` - the current session ID
    * `persistent?` - a flag to check if the login is persistent
    * `created_at` - the initial login date
    * `last_login` - the date of last login using this serial
    * `last_ip` - the last IP used to login with this serial
    * `last_useragent` - the last user agent used to login
  """

  defstruct [
    :username,
    :serial,
    :token,
    :sid,
    :persistent?,
    :created_at,
    :last_login,
    :last_ip,
    :last_useragent,
  ]

  @typedoc "A login"
  @type t :: %__MODULE__{
    username: String.t,
    serial: String.t,
    token: String.t,
    sid: String.t | nil,
    persistent?: boolean,
    created_at: Calendar.datetime,
    last_login: Calendar.datetime,
    last_ip: :inet.ip_address,
    last_useragent: String.t,
  }
end
