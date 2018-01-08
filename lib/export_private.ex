defmodule ExportPrivate do
  @moduledoc """
  Export private functions for tests.
  """

  defmacro __using__(_) do
    quote do
      import Kernel, except: [defp: 2]
      import ExportPrivate
    end
  end

  defmacro defp(call, do: block) do
    if Mix.env() == :test do
      quote do
        def unquote(call), do: unquote(block)
      end
    else
      quote do
        defp unquote(call), do: unquote(block)
      end
    end
  end
end
