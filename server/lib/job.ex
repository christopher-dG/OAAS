defmodule ReplayFarm.Job do
  @moduledoc "Jobs are recording/uploading tasks to be completed."

  alias ReplayFarm.Model

  @table "jobs"

  @derive Jason.Encoder
  @enforce_keys [:id, :player, :beatmap, :replay, :status, :created_at, :updated_at]
  defstruct [
    :id,
    :player,
    :beatmap,
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

  use Model
end
