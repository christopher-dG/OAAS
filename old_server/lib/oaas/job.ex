defmodule OAAS.Job do
  @moduledoc "An abstract job to be completed."

  alias OAAS.DB
  alias OAAS.Job.Replay
  alias OAAS.Worker
  import OAAS.Utils
  require DB

  @table "jobs"

  @derive Jason.Encoder
  @enforce_keys [:id, :type, :data, :status, :created_at, :updated_at]
  defstruct @enforce_keys ++ [:comment, :worker_id]

  @type t :: %__MODULE__{
          id: integer,
          type: integer,
          data: map,
          status: integer,
          comment: String.t() | nil,
          worker_id: String.t() | nil,
          created_at: integer,
          updated_at: integer
        }

  @json_columns [:data]

  use OAAS.Model

  @doc "Defines the job status enum."
  def status(_s)

  @spec status(atom) :: integer
  def status(:pending), do: 0
  def status(:assigned), do: 1
  def status(:preparing), do: 2
  def status(:executing), do: 3
  def status(:cleanup), do: 4
  def status(:recording), do: 5
  def status(:uploading), do: 6
  # These ones belong here at the end, as we want to skip them when checking for stalls.
  def status(:successful), do: 7
  def status(:failed), do: 8
  def status(:deleted), do: 9

  @spec status(integer) :: atom
  def status(0), do: :pending
  def status(1), do: :assigned
  def status(2), do: :preparing
  def status(3), do: :executing
  def status(4), do: :cleanup
  def status(5), do: :recording
  def status(6), do: :uploading
  def status(7), do: :successful
  def status(8), do: :failed
  def status(9), do: :deleted

  @doc "Defines the job type enum."
  def type(_)

  @spec type(module) :: integer
  def type(Replay), do: 0

  @spec type(integer) :: module
  def type(0), do: Replay

  @doc "Describes a job."
  @spec describe(t) :: String.t()
  def describe(j) do
    """
    ID: #{j.id}
    Worker: #{j.worker_id || "None"}
    Status: #{j.status |> status() |> to_string() |> String.capitalize()}
    Comment: #{j.comment || "None"}
    Created: #{relative_time(j.created_at)}
    Updated: #{relative_time(j.updated_at)}
    """
    |> String.trim()
  end

  @doc "Checks whether a job is finished."
  @spec finished(t) :: boolean
  def finished(j) do
    status(j.status) in [:successful, :failed, :deleted]
  end

  @doc "Marks a job as deleted, but leaves it in the database."
  @spec mark_deleted(t) :: {:ok, t} | {:error, term}
  def mark_deleted(j) do
    DB.transaction(fn ->
      unless is_nil(j.worker_id) do
        with {:ok, w} <- Worker.get(j.worker_id),
             {:ok, _} <- Worker.update(w, current_job_id: nil) do
          :noop
        else
          {:error, reason} -> throw(reason)
        end
      end

      case update(j, worker_id: nil, status: status(:deleted)) do
        {:ok, j} -> j
        {:error, reason} -> throw(reason)
      end
    end)
  end

  @timeouts %{
    assigned: 90 * 1000,
    preparing: 120 * 1000,
    executing: 30 * 60 * 1000,
    cleanup: 60 * 1000,
    recording: 10 * 60 * 1000,
    uploading: 10 * 60 * 1000
  }

  @doc "Gets all jobs which are running but stalled."
  @spec get_stalled :: {:ok, [t]} | {:error, term}
  def get_stalled do
    case query("SELECT * FROM #{@table} WHERE status BETWEEN ?1 AND ?2", [
           status(:assigned),
           status(:uploading)
         ]) do
      {:ok, js} ->
        {:ok,
         Enum.filter(js, fn j -> abs(now() - j.updated_at) > @timeouts[status(j.status)] end)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Gets all jobs with a given status."
  @spec get_by_status(atom | integer) :: {:ok, [t]} | {:error, term}
  def get_by_status(stat) when is_atom(stat) do
    stat
    |> status()
    |> get_by_status()
  end

  def get_by_status(stat) when is_integer(stat) do
    query("SELECT * FROM #{@table} WHERE status = ?1", [stat])
  end

  @doc "Assigns a job to a worker."
  @spec assign(t, Worker.t()) :: {:ok, t} | {:error, term}
  def assign(j, w) do
    DB.transaction(fn ->
      with {:ok, _} <- Worker.update(w, current_job_id: j.id, last_job: now()),
           {:ok, j} <- update(j, worker_id: w.id, status: status(:assigned)) do
        j
      else
        {:error, reason} -> throw(reason)
      end
    end)
  end

  @doc "Updates a job's status."
  @spec update_status(t, Worker.t(), integer, String.t()) :: {:ok, t} | {:error, term}
  def update_status(j, w, stat, comment) do
    DB.transaction(fn ->
      case update(j, status: stat, comment: comment) do
        {:ok, j} ->
          if finished(j) do
            case Worker.update(w, current_job_id: nil) do
              {:ok, _w} -> j
              {:error, reason} -> throw(reason)
            end
          else
            j
          end

        {:error, reason} ->
          throw(reason)
      end
    end)
  end

  @doc "Fails a job."
  @spec fail(t, String.t()) :: {:ok, t} | {:error, term}
  def fail(j, comment \\ "") do
    DB.transaction(fn ->
      with {:ok, w} <- Worker.get(j.worker_id),
           {:ok, _w} <- Worker.update(w, current_job_id: nil),
           {:ok, j} <- update(j, worker_id: nil, status: status(:failed), comment: comment) do
        j
      else
        {:error, reason} -> throw(reason)
      end
    end)
  end
end
