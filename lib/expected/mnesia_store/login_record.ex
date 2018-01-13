defmodule Expected.MnesiaStore.LoginRecord do
  @moduledoc """
  Login record for the Mnesia store.
  """

  import Record

  alias Expected.Login

  {keys, types} = Login.fields() |> Enum.unzip()
  values = Enum.map(keys, &{&1, [], nil})
  pairs = Enum.zip(keys, values)

  defrecord :login, Enum.map(keys, &{&1, :_})

  @typedoc "A login record"
  @type t() :: {:login, unquote_splicing(types)}

  @doc """
  Creates a login record from an `Expected.Login`.
  """
  @spec from_struct(Login.t()) :: t()
  def from_struct(%Login{unquote_splicing(pairs)}) do
    {:login, unquote_splicing(values)}
  end

  @doc """
  Creates an `Expected.Login` from a login record.
  """
  @spec to_struct(t()) :: Login.t()
  def to_struct({:login, unquote_splicing(values)}) do
    %Login{unquote_splicing(pairs)}
  end
end
