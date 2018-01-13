defmodule Expected.NotLoadedUser do
  @moduledoc """
  A struct for representing a not-loaded user field.

  ## Fields

    * `username` - the user’s username
  """

  defstruct [:username]

  @typedoc "A not-loaded user"
  @type t() :: %__MODULE__{username: String.t()}
end
