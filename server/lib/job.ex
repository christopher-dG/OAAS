defmodule ReplayFarm.Job do
  @moduledoc "Jobs are recording/uploading tasks to be completed."

  @status %{
    pending: 0,
    assigned: 1,
    recording: 2,
    uploading: 3,
    successful: 4,
    failed: 5
  }

  @doc "Accesses the job status enum."
  def status(k) when is_atom(k) do
    @status[k]
  end

  @doc "Checks whether a status indicates that the job is finished."
  @spec finished(integer) :: boolean
  def finished(stat) when is_integer(stat) do
    stat > status(:successful)
  end

  @table "jobs"

  @derive Jason.Encoder
  @enforce_keys [:id, :player, :beatmap, :mode, :replay, :status, :created_at, :updated_at]
  defstruct [
    :id,
    :player,
    :beatmap,
    :mode,
    :replay,
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
          player: map,
          beatmap: map,
          mode: integer,
          replay: binary,
          skin: map | nil,
          post: map | nil,
          status: integer,
          comment: binary | nil,
          worker_id: binary | nil,
          created_at: integer,
          updated_at: integer
        }

  @json_columns [:player, :beatmap, :skin, :post]

  use ReplayFarm.Model

  @skins_api "https://circle-people.com/skins-api.php?player="

  @doc "Gets the skin URL for a user."
  @spec skin(map) :: binary | nil
  def skin(%{username: username}) do
    case HTTPoison.get(@skins_api <> username) do
      {:ok, resp} ->
        if resp.body === "" do
          Logger.warn("no skin available for user #{username}")
          nil
        else
          resp.body
        end

      {:error, err} ->
        Logger.warn("couldn't get skin for user #{username}: #{inspect(err)}")
        nil
    end
  end
end
