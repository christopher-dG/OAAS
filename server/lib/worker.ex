defmodule ReplayFarm.Worker do
  @moduledoc "Workers are clients that can complete jobs."

  alias ReplayFarm.Model
  alias ReplayFarm.DB
  alias ReplayFarm.Job

  @table "workers"

  @enforce_keys [:id, :last_poll, :created_at, :updated_at]
  defstruct [:id, :last_poll, :last_job, :current_job_id, :created_at, :updated_at]

  @type t :: %__MODULE__{
          id: binary,
          last_poll: integer,
          last_job: integer,
          current_job_id: integer,
          created_at: integer,
          updated_at: integer
        }

  @json_columns []

  @online_threshold 30_000

  @doc "Gets all online workers."
  @spec get(:online) :: {:ok, [t]} | {:error, term}
  def get(:online) do
    sql = "SELECT * FROM #{@table} WHERE ABS(?1 - last_poll) <= ?2"

    case DB.query(sql, bind: [System.system_time(:millisecond), @online_threshold]) do
      {:ok, ws} -> {:ok, Enum.map(ws, &struct(__MODULE__, &1))}
      {:error, err} -> {:error, err}
    end
  end

  use Model

  @doc "Gets the worker's currently assigned job."
  @spec get_assigned(binary | t) :: {:ok, Job.t() | nil} | {:error, term}
  def get_assigned(_w)

  def get_assigned(id) when is_binary(id) do
    case get(id) do
      {:ok, w} -> get_assigned(w)
      {:error, err} -> {:error, err}
    end
  end

  def get_assigned(%__MODULE__{} = w) do
    if(is_nil(w.current_job_id), do: {:ok, nil}, else: Job.get(w.current_job_id))
  end
end
