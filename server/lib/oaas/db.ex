defmodule OAAS.DB do
  @moduledoc "Wraps the SQLite3 database."

  import OAAS.Utils

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
    Enum.each(@schema, fn sql ->
      case Sqlitex.Server.query(__MODULE__, sql) do
        {:ok, _} ->
          :noop

        {:error, reason} ->
          unless String.starts_with?(sql, "ALTER TABLE") do
            notify(:debug, "schema query failed: #{inspect(reason)}\n#{sql}")
          end
      end
    end)

    {:ok, self()}
  end

  @doc "Wrapper around `Sqlitex.Server.query`."
  @spec query(String.t(), keyword) :: {:ok, list} | {:error, term}
  def query(sql, opts \\ []) do
    s = "sql: #{sql}"
    nobind = Keyword.drop(opts, [:bind])
    s = if(Enum.empty?(nobind), do: s, else: "#{s}\nopts: #{inspect(nobind)}")
    bind = Keyword.get(opts, :bind, [])
    bind_s = inspect(bind, pretty: true, printable_limit: 80)
    s = if(Enum.empty?(bind), do: s, else: "#{s}\nbind: #{bind_s}")
    notify(:debug, s)

    case Sqlitex.Server.query(__MODULE__, sql, opts) do
      {:ok, results} ->
        notify(:debug, "query ok: #{length(results)} result(s)")
        {:ok, results}

      {:error, reason} ->
        notify(:debug, "query error", reason)
        {:error, reason}
    end
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
