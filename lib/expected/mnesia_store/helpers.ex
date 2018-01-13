defmodule Expected.MnesiaStore.Helpers do
  @moduledoc """
  Helpers for creating the Mnesia table.

  You can use the functions in this module to create the Mnesia table used by
  `Expected.MnesiaStore` on the current node. If you want more advanced features
  like distribution, you should create the table yourself.
  """

  alias Expected.Login
  alias Expected.ConfigurationError
  alias Expected.MnesiaTableExistsError

  @typep persistence() :: :persistent | :volatile
  @typep return_value() :: :ok | {:error | :abort, term()}

  @attributes Login.keys()

  table_config = """
  For this function to work, `:table` must be set in your `config.exs`:

      config :expected,
        store: :mnesia,
        table: :logins,
        ...
  """

  @doc """
  Sets up the Mnesia table for login storage according to the configuration.

  #{table_config}

  It then creates a Mnesia table with copies in RAM and on disk, so that logins
  are persistent accross application reboots. For more information about the
  process, see `setup/2`.

  If the table already exists *with different attributes*, an
  `Expected.MnesiaTableExistsError` is raised.
  """
  @spec setup! :: :ok
  def setup! do
    fetch_table_name!() |> do_setup!()
  end

  @doc """
  Clears all logins from the Mnesia table given in the configuration.

  #{table_config}
  """
  @spec clear! :: :ok
  def clear! do
    fetch_table_name!() |> clear()
  end

  @doc """
  Drops the Mnesia table given in the configuration.

  #{table_config}
  """
  @spec drop! :: :ok
  def drop! do
    fetch_table_name!() |> drop()
  end

  @doc """
  Creates a Mnesia table for login storage.

  ## Parameters

  * `table` - Mnesia table name
  * `persistent?` - persistence mode. `:persistent` automatically sets the
    schema and the table to keep a copy of their data in both RAM and disk.
    `:volatile` lets the schema copy mode untouched and creates a RAM-only
    login store.

  ## Return values

  * `:ok` - the table has been successfully created
  * `{:error, :already_exists}` - a table with the same name but different
    attribute already exists. If the table has the correct attributes, there is
    no error.
  * Any other error from Mnesia

  ## Examples

      iex> Expected.MnesiaStore.Helpers.setup(:logins)
      :ok
      iex> :mnesia.create_table(:test, [attributes: [:id, :data]])
      {:atomic, :ok}
      iex> Expected.MnesiaStore.Helpers.setup(:test)
      {:error, already_exists}
  """
  @spec setup(atom()) :: return_value()
  @spec setup(atom(), :persistent | :volatile) :: return_value()
  def setup(table, persistent? \\ :persistent)
      when is_atom(table) and persistent? in [:persistent, :volatile] do
    {:mnesia.start(), persistent?}
    |> create_schema()
    |> create_table(table)
  end

  @doc """
  Clears all logins from the `table`.
  """
  @spec clear(atom()) :: :ok
  def clear(table) do
    :mnesia.clear_table(table)
    :ok
  end

  @doc """
  Drops the Mnesia `table`.
  """
  @spec drop(atom()) :: :ok
  def drop(table) do
    :mnesia.delete_table(table)
    :ok
  end

  ##
  ## Private helpers
  ##

  @spec fetch_table_name! :: atom()
  defp fetch_table_name! do
    case Application.fetch_env(:expected, :table) do
      {:ok, table} -> table
      :error -> raise ConfigurationError, reason: :no_mnesia_table
    end
  end

  @spec do_setup!(atom()) :: :ok
  defp do_setup!(table) do
    case setup(table) do
      :ok -> :ok
      {:error, :table_exists} -> raise MnesiaTableExistsError, table: table
    end
  end

  @spec create_schema({term(), persistence()}) ::
          {return_value(), persistence()}

  defp create_schema({:ok, :persistent} = status) do
    # Just keep it for the else clause.
    node = node()

    with [] <- :mnesia.table_info(:schema, :disc_copies),
         {:atomic, :ok} <- persist_schema() do
      status
    else
      # If the node is already in the disc_copies, alright!
      [^node] ->
        status

      other ->
        {other, :persistent}
    end
  end

  defp create_schema(status), do: status

  @spec persist_schema :: {:atomic, :ok} | {:aborted, term()}
  defp persist_schema,
    do: :mnesia.change_table_copy_type(:schema, node(), :disc_copies)

  @spec create_table({term(), persistence()}, atom()) :: return_value()
  defp create_table({:ok, persistent?}, table) do
    disc_copies =
      if persistent? == :persistent,
        do: [node()],
        else: []

    table_def = [
      type: :bag,
      record_name: :login,
      attributes: @attributes,
      index: [:serial, :last_login],
      disc_copies: disc_copies
    ]

    case :mnesia.create_table(table, table_def) do
      {:atomic, :ok} ->
        :ok

      {:aborted, {:already_exists, ^table}} ->
        if :mnesia.table_info(table, :attributes) == @attributes,
          # If the existing table is the same, it’s OK.
          do: :ok,
          else: {:error, :table_exists}
    end
  end

  defp create_table({status, _}, _table), do: status
end
