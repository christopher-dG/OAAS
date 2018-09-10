defmodule ReplayFarm.Worker do
  @moduledoc "Workers are clients that can complete jobs."

  require Logger

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

  use ReplayFarm.Model

  @online_threshold 30 * 1000

  @doc "Gets all online workers."
  @spec get_online! :: [t]
  def get_online! do
    query!(
      "SELECT * FROM #{@table} WHERE ABS(?1 - last_poll) <= ?2",
      x: System.system_time(:millisecond),
      x: @online_threshold
    )
    |> Enum.map(&struct(__MODULE__, &1))
  end

  @doc "Gets the worker's currently assigned job."
  def get_assigned!(_w)

  @spec get_assigned!(binary) :: Job.t() | nil
  def get_assigned!(id) when is_binary(id) do
    get!(id) |> get_assigned!()
  end

  @spec get_assigned!(t) :: Job.t() | nil
  def get_assigned!(%__MODULE__{} = w) do
    if is_nil(w.current_job_id) do
      nil
    else
      assigned = Job.status(:assigned)

      case Job.get!(w.current_job_id) do
        %Job{status: ^assigned} = j -> j
        _ -> nil
      end
    end
  end

  @doc "Retrieves a worker, or creates a new one."
  @spec get_or_put!(binary) :: t
  def get_or_put!(id) when is_binary(id) do
    # We could do one less query with "INSERT OR IGNORE" but it's not worth the effort.
    case get!(id) do
      nil -> Logger.info("Inserting new worker #{id}") && put!(id: id)
      w -> w
    end
  end

  @doc "Chooses an online worker by LRU."
  @spec get_lru! :: t | nil
  def get_lru! do
    case get_online!() do
      [] ->
        nil

      ws ->
        ws
        |> Enum.sort_by(fn w -> w.last_job || 0 end)
        |> hd()
    end
  end
end
