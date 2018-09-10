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
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )",
    "CREATE TABLE IF NOT EXISTS jobs(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      player TEXT NOT NULL,   -- JSON
      beatmap TEXT NOT NULL,  -- JSON
      mode INTEGER NOT NULL,
      replay TEXT NOT NULL,
      skin TEXT,  -- JSON
      post TEXT,  -- JSON
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
  @spec query!(binary, keyword) :: list
  def query!(sql, opts \\ []) when is_binary(sql) and is_list(opts) do
    case Sqlitex.Server.query(__MODULE__, sql, opts) do
      {:ok, results} -> results
      {:error, err} -> raise inspect(err)
    end
  end

  @doc "Executes some code inside of a SQL transaction."
  defmacro transaction!(do: expr) do
    quote do
      import ReplayFarm.DB, only: [query!: 1]
      query!("BEGIN")

      try do
        result = unquote(expr)
        query!("COMMIT")
        result
      rescue
        e -> query!("ROLLBACK") && raise e
      end
    end
  end
end
