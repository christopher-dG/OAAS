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
      {:ok, workers} -> {:ok, Enum.map(workers, &from_map/1)}
      {:error, err} -> {:error, err}
    end
  end

  @doc "Gets a worker by ID."
  @spec get_worker(binary) :: {:ok, t} | {:error, term}
  def get_worker(id) when is_binary(id) do
    sql = "SELECT * FROM #{@table} WHERE id = ?1"

    case DB.query(sql, bind: [id]) do
      {:ok, [worker]} -> {:ok, from_map(worker)}
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
      {:ok, workers} -> {:ok, Enum.map(workers, &from_map/1)}
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

  @doc "Gets the worker's currently assigned job."
  @spec get_assigned(binary) :: {:ok, Job.t() | nil} | {:error, term}
  def get_assigned(id) when is_binary(id) do
    case get_worker(id) do
      {:ok, worker} ->
        if is_nil(worker.current_job_id) do
          {:ok, nil}
        else
          Job.get_job(worker.current_job_id)
        end

      {:error, err} ->
        {:error, err}
    end
  end

  # Convert a worker map to a struct.
  defp from_map(%{id: id, last_poll: lp, last_job: lj, current_job_id: cri, created_at: ca}) do
    %__MODULE__{id: id, last_poll: lp, last_job: lj, current_job_id: cri, created_at: ca}
  end
end
