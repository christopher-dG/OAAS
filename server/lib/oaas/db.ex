defmodule OAAS.DB do
  @moduledoc "The database wrapper."

  @schema [
    "CREATE TABLE IF NOT EXISTS keys(
      id TEXT PRIMARY KEY,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )",
    "CREATE TABLE IF NOT EXISTS workers(
      id TEXT PRIMARY KEY,
      last_poll INTEGER DEFAULT 0,
      last_job INTEGER,
      current_job_id INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )",
    "CREATE TABLE IF NOT EXISTS jobs(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type INTEGER NOT NULL,
      data TEXT NOT NULL,
      status INTEGER NOT NULL,
      comment TEXT,
      worker_id TEXT REFERENCES workers(id),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )",
    # This one is going to fail whenver the column already exists but whatever.
    "ALTER TABLE workers ADD COLUMN current_job_id REFERENCES jobs(id) ON DELETE SET NULL"
  ]

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def start_link(_opts) do
    Enum.each(@schema, fn sql -> Sqlitex.Server.query(__MODULE__, sql) end)
    {:ok, self()}
  end

  @doc "Wrapper around `Sqlitex.Server.query`."
  @spec query(String.t(), keyword) :: {:ok, list} | {:error, term}
  def query(sql, opts \\ []) do
    Sqlitex.Server.query(__MODULE__, sql, opts)
  end

  @doc """
  Executes some code inside of a SQL transaction.
  The transaction will roll back if an exception is raised or something is thrown.
  The return value is either `{:ok, return}` where `return` is the return value of the block,
  or `{:error, reason}` where `reason` was thrown or raised.
  """
  @spec transaction(term) :: {:ok, term} | {:error, term}
  defmacro transaction(do: expr) do
    quote do
      tx_cmd = fn cmd ->
        case OAAS.DB.query(String.upcase(cmd)) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            OAAS.Utils.notify(:error, "transaction #{String.downcase(cmd)} failed", reason)
            {:error, reason}
        end
      end

      try do
        case tx_cmd.("begin") do
          :ok -> :noop
          {:error, reason} -> throw(reason)
        end

        results = unquote(expr)

        case tx_cmd.("commit") do
          :ok -> :noop
          {:error, reason} -> throw(reason)
        end

        {:ok, results}
      rescue
        reason ->
          tx_cmd.("rollback")
          {:error, reason}
      catch
        reason ->
          tx_cmd.("rollback")
          {:error, reason}
      end
    end
  end
end
