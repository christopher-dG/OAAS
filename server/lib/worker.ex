defmodule ReplayFarm.Worker do
  @moduledoc "Workers are clients that can complete jobs."

  alias ReplayFarm.DB
  alias ReplayFarm.Job

  @table "workers"
  @online_threshold 30_000

  @enforce_keys [:id]
  defstruct [:id, :last_poll, :last_job, :current_job_id, :created_at]

  @type t :: %__MODULE__{
          id: binary,
          last_poll: integer,
          last_job: integer,
          current_job_id: integer,
          created_at: integer
        }

  @doc "Gets all workers."
  @spec get_workers :: {:ok, [t]} | {:error, term}
  def get_workers do
    sql = "SELECT * FROM #{@table}"

    case DB.query(sql) do
      {:ok, workers} -> {:ok, Enum.map(workers, &struct(__MODULE__, &1))}
      {:error, err} -> {:error, err}
    end
  end

  @doc "Gets a worker by ID."
  @spec get_worker(binary) :: {:ok, t} | {:error, term}
  def get_worker(id) when is_binary(id) do
    sql = "SELECT * FROM #{@table} WHERE id = ?1"

    case DB.query(sql, bind: [id]) do
      {:ok, [worker]} -> {:ok, struct(__MODULE__, worker)}
      {:ok, []} -> {:error, :worker_not_found}
      {:error, err} -> {:error, err}
      _ -> {:error, :unknown}
    end
  end

  @doc "Gets all online workers."
  @spec get_online_workers :: {:ok, [t]} | {:error, term}
  def get_online_workers do
    sql = "SELECT * FROM #{@table} WHERE ABS(?1 - last_poll) <= ?2"

    case DB.query(sql, bind: [System.system_time(:millisecond), @online_threshold]) do
      {:ok, workers} -> {:ok, Enum.map(workers, &struct(__MODULE__, &1))}
      {:error, err} -> {:error, err}
    end
  end

  @doc "Inserts a new worker."
  @spec put_worker(binary) :: {:ok, t} | {:error, term}
  def put_worker(id) do
    now = System.system_time(:millisecond)
    sql = "INSERT INTO #{@table} (id, last_poll, created_at) VALUES (?1, ?2, ?3)"

    case DB.query(sql, bind: [id, now, now]) do
      {:ok, _} -> {:ok, %__MODULE__{id: id, last_poll: now, created_at: now}}
      {:error, err} -> {:error, err}
    end
  end

  @doc "Updates a worker."
  @spec update_worker(binary | t, map) :: {:ok, t} | {:error, term}
  def update_worker(_w, _v)

  def update_worker(id, vals) when is_binary(id) and is_map(vals) do
    case get_worker(id) do
      {:ok, w} -> update_worker(w, vals)
      {:error, err} -> {:error, err}
    end
  end

  def update_worker(%__MODULE__{} = worker, vals) when is_map(vals) do
    save_worker(Map.merge(worker, vals))
  end

  @doc "Gets the worker's currently assigned job."
  @spec get_assigned(binary | t) :: {:ok, Job.t() | nil} | {:error, term}
  def get_assigned(_w)

  def get_assigned(id) when is_binary(id) do
    case get_worker(id) do
      {:ok, w} -> get_assigned(w)
      {:error, err} -> {:error, err}
    end
  end

  def get_assigned(%__MODULE__{} = worker) do
    if is_nil(worker.current_job_id) do
      {:ok, nil}
    else
      Job.get_job(worker.current_job_id)
    end
  end

  # Saves any updated worker fields to the database.
  @spec save_worker(binary | t) :: {:ok, t} | {:error, term}
  defp save_worker(%__MODULE__{} = worker) do
    sql = "UPDATE #{@table} SET last_poll = ?1, last_job = ?2, current_job_id = ?3 WHERE id = ?4"

    binds = [
      worker.last_poll,
      worker.last_job,
      worker.current_job_id,
      worker.id
    ]

    case DB.query(sql, bind: binds) do
      {:ok, w} -> {:ok, struct(__MODULE__, w)}
      {:error, err} -> {:error, err}
    end
  end
end
