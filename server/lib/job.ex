defmodule ReplayFarm.Job do
  @moduledoc "Jobs are recording/uploading tasks to be completed."

  require Logger

  @doc "Defines the job status enum."
  def status(_s)

  @spec status(atom) :: integer
  def status(:pending), do: 0
  def status(:assigned), do: 1
  def status(:recording), do: 2
  def status(:uploading), do: 3
  def status(:successful), do: 4
  def status(:failed), do: 5

  @spec status(integer) :: atom
  def status(0), do: :pending
  def status(1), do: :assigned
  def status(2), do: :recording
  def status(3), do: :uploading
  def status(4), do: :successful
  def status(5), do: :failed

  @doc "Checks whether a status indicates that the job is finished."
  @spec finished(integer) :: boolean
  def finished(stat) when is_integer(stat) do
    stat >= status(:successful)
  end

  @table "jobs"

  @derive Jason.Encoder
  @enforce_keys [:id, :beatmapset_id, :replay, :youtube, :status, :created_at, :updated_at]
  defstruct [
    :id,
    :beatmapset_id,
    :replay,
    :youtube,
    :skin,
    :post,
    :status,
    :comment,
    :worker_id,
    :created_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: integer,
          beatmapset_id: integer,
          replay: binary,
          youtube: map,
          skin: map | nil,
          post: map | nil,
          status: integer,
          comment: binary | nil,
          worker_id: binary | nil,
          created_at: integer,
          updated_at: integer
        }

  @json_columns [:skin, :youtube, :post]

  use ReplayFarm.Model

  @skins_api "https://circle-people.com/skins-api.php?player="

  @doc "Gets the skin name and URL for a user."
  @spec skin(map) :: map | nil
  def skin(%{username: username}) do
    case HTTPoison.get(@skins_api <> username) do
      {:ok, resp} ->
        if resp.body === "" do
          Logger.warn("No skin available for user #{username}")
          nil
        else
          %{
            name: resp.body |> String.split("/") |> List.last() |> String.trim_trailing(".osk"),
            url: resp.body
          }
        end

      {:error, err} ->
        Logger.warn("Couldn't get skin for user #{username}: #{inspect(err)}")
        nil
    end
  end

  @timeouts %{
    assigned: 90 * 1000,
    recording: 10 * 60 * 1000,
    uploading: 10 * 60 * 1000
  }

  @doc "Gets all jobs which are running but stalled."
  @spec get_stalled! :: [t]
  def get_stalled! do
    now = System.system_time(:millisecond)

    query!(
      "SELECT * FROM #{@table} WHERE status BETWEEN ?1 AND ?2",
      x: status(:assigned),
      x: status(:uploading)
    )
    |> Enum.flat_map(fn j ->
      if abs(now - j.updated_at) < @timeouts[status(j.status)] do
        []
      else
        [struct(__MODULE__, j)]
      end
    end)
  end

  @doc "Gets all pending jobs."
  @spec get_pending! :: [t]
  def get_pending! do
    query!("SELECT * FROM #{@table} WHERE status = ?1", x: status(:pending))
    |> Enum.map(&struct(__MODULE__, &1))
  end
end
