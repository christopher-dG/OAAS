defmodule ReplayFarm.DB do
  @moduledoc "The database wrapper."

  @schema [
    "CREATE TABLE IF NOT EXISTS keys(
      key TEXT PRIMARY KEY
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
      player TEXT NOT NULL,   -- JSON
      beatmap TEXT NOT NULL,  -- JSON
      youtube TEXT NOT NULL,  -- JSON
      replay TEXT NOT NULL,   -- JSON
      status INTEGER NOT NULL,
      skin TEXT,  -- JSON
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
  @spec query(binary, keyword) :: {:ok, list} | {:error, term}
  def query(sql, opts \\ []) do
    Sqlitex.Server.query(__MODULE__, sql, opts)
  end

  @doc "Executes some code inside of a SQL transaction."
  defmacro transaction(do: expr) do
    quote do
      with {:ok, _} <- ReplayFarm.DB.query("BEGIN"),
           {:ok, results} <- unquote(expr),
           {:ok, _} <- ReplayFarm.DB.query("COMMIT") do
        {:ok, results}
      else
        {:error, err} -> ReplayFarm.DB.query("ROLLBACK") && {:error, err}
      end
    end
  end
end
