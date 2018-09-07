defmodule ReplayFarm.DB do
  @moduledoc "The database wrapper."

  require Logger

  @schema [
    "CREATE TABLE IF NOT EXISTS keys(
      key TEXT PRIMARY KEY
    )",
    "CREATE TABLE IF NOT EXISTS workers(
      id TEXT PRIMARY KEY,
      last_poll INTEGER NOT NULL,
      last_job INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )",
    "CREATE TABLE IF NOT EXISTS jobs(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      player TEXT NOT NULL,   -- JSON
      beatmap TEXT NOT NULL,  -- JSON
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
    Enum.each(@schema, fn sql -> Sqlitex.Server.query(ReplayFarm.DB, sql) end)
    {:ok, self()}
  end

  @doc "Starts the database (useful when running with --no-start)."
  def start do
    File.mkdir_p("priv")
    Sqlitex.Server.start_link("priv/db_#{Mix.env()}.sqlite3", name: ReplayFarm.DB)
    start_link([])
  end

  @doc "Execute a database query."
  @spec query!(binary, keyword) :: list
  def query!(sql, opts \\ []) when is_binary(sql) and is_list(opts) do
    {decode, opts} = Keyword.pop(opts, :decode, [])

    case Sqlitex.Server.query(ReplayFarm.DB, sql, opts) do
      {:ok, results} ->
        if String.starts_with?(String.upcase(sql), "SELECT") do
          Enum.map(results, fn row ->
            Enum.map(row, fn {k, v} ->
              if k in decode do
                case Jason.decode(v) do
                  {:ok, decoded} ->
                    {k, decoded}

                  {:error, err} ->
                    Logger.warn("couldn't decode column #{k}: #{inspect(err)}")
                    {k, v}
                end
              else
                {k, v}
              end
            end)
            |> Map.new()
          end)
        else
          results
        end

      {:error, err} ->
        raise inspect(err)
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
