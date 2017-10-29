## This file defines exceptions for Expected.

defmodule Expected.ConfigurationError do
  @moduledoc """
  Error raised when the configuration is invalid or incomplete.
  """

  defexception [:reason]

  def message(%{reason: :no_process_name}) do
    """
    Process name not configured for the `:memory` store.

    You must set a process name for the `:memory` store in the configuration:

        config :expected,
          store: :memory,
          process_name: :test_store
    """
  end
end
