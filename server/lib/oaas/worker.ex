defmodule OAAS.Worker do
  @moduledoc "Workers are clients that can complete jobs."

  alias OAAS.Job

  @table "workers"

  @enforce_keys [:id, :last_poll, :created_at, :updated_at]
  defstruct @enforce_keys ++ [:last_job, :current_job_id]

  @type t :: %__MODULE__{
          id: String.t(),
          last_poll: integer,
          last_job: integer | nil,
          current_job_id: integer | nil,
          created_at: integer,
          updated_at: integer
        }

  @json_columns []

  use OAAS.Model

  @doc "Describes the worker."
  @spec describe(t) :: String.t()
  def describe(w) do
    """
    ```yml
    id: #{w.id}
    online: #{online?(w)}
    job: #{w.current_job_id || "none"}
    last poll: #{relative_time(w.last_poll)}
    last job: #{relative_time(w.last_job)}
    created: #{relative_time(w.created_at)}
    updated: #{relative_time(w.updated_at)}
    ```
    """
  end

  @online_threshold 30 * 1000

  @doc "Determines whether a worker is online."
  @spec online?(t) :: boolean
  def online?(w) do
    System.system_time(:millisecond) - (w.last_poll || 0) <= @online_threshold
  end

  @doc "Gets all available workers (online + not busy)."
  @spec get_available :: {:ok, [t]} | {:error, term}
  def get_available do
    query(
      "SELECT * FROM #{@table} WHERE current_job_id IS NULL AND ?1 - last_poll <= ?2",
      [System.system_time(:millisecond), @online_threshold]
    )
  end

  @doc "Gets the worker's currently assigned job."
  @spec get_assigned(t) :: {:ok, Job.t() | nil} | {:error, term}
  def get_assigned(%{current_job_id: nil}) do
    {:ok, nil}
  end

  def get_assigned(%{current_job_id: id}) do
    ass = Job.status(:assigned)

    case Job.get(id) do
      {:ok, %Job{status: ^ass} = j} -> {:ok, j}
      {:ok, _j} -> {:ok, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Retrieves a worker, or creates a new one."
  @spec get_or_put(String.t()) :: {:ok, t} | {:error, term}
  def get_or_put(id) do
    case get(id) do
      {:ok, w} -> {:ok, w}
      {:error, :no_such_entity} -> put(id: id)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Chooses an online worker by LRU."
  @spec get_lru :: {:ok, t | nil} | {:error, term}
  def get_lru do
    case get_available() do
      {:ok, []} ->
        {:ok, nil}

      {:ok, ws} ->
        {:ok,
         ws
         |> Enum.sort_by(fn w -> w.last_job || 0 end)
         |> hd()}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
