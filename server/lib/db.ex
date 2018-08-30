defmodule ReplayFarm.DB do
  @moduledoc "Defines and executes the schema at startup."

  require Logger

  @schema [
    "CREATE TABLE IF NOT EXISTS keys(
      key TEXT PRIMARY KEY
	)",
    "CREATE TABLE IF NOT EXISTS workers(
      id TEXT PRIMARY KEY,
      last_poll INTEGER NOT NULL,
      last_job INTEGER,
      created_at INTEGER NOT NULL
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

  @doc "Helper function to start the database when nothing else is running."
  def start, do: Sqlitex.Server.start_link("priv/db_#{Mix.env()}.sqlite3", name: ReplayFarm.DB)

  @doc "Execute a database query."
  def query(query, opts \\ []) when is_binary(query) and is_list(opts) do
    {decode, opts} = Keyword.pop(opts, :decode, [])

    case Sqlitex.Server.query(ReplayFarm.DB, query, opts) do
      {:ok, results} ->
        if String.starts_with?(String.upcase(query), "SELECT") do
          {:ok,
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
           end)}
        else
          {:ok, results}
        end

      {:error, err} ->
        {:error, err}
    end
  end
end
