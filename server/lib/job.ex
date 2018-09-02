defmodule ReplayFarm.Job do
  @moduledoc "Jobs are recording/uploading tasks to be completed."

  alias ReplayFarm.DB

  @table "jobs"
  @status %{
    pending: 0,
    assigned: 1,
    acknowledged: 2,
    recording: 3,
    uploading: 4,
    successful: 5,
    failed: 6,
    backlogged: 7
  }

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

  @doc "Gets all jobs."
  @spec get_jobs :: {:ok, [t]} | {:error, term}
  def get_jobs do
    sql = "SELECT * FROM #{@table}"

    case DB.query(sql, decode: @json_columns) do
      {:ok, jobs} -> {:ok, Enum.map(jobs, &struct(__MODULE__, &1))}
      {:error, err} -> {:error, err}
    end
  end

  @doc "Gets a job by ID."
  @spec get_job(integer) :: {:ok, t} | {:error, term}
  def get_job(id) when is_integer(id) do
    sql = "SELECT * FROM #{@table} WHERE id = ?1"

    case DB.query(sql, bind: [id]) do
      {:ok, [job]} -> {:ok, struct(__MODULE__, job)}
      {:ok, []} -> {:error, :job_not_found}
      {:error, err} -> {:error, err}
      _ -> {:error, :unknown}
    end
  end

  @doc "Inserts a new job."
  @spec put_job(map, map, binary, map | nil, map | nil) :: {:ok, t} | {:error, term}
  def put_job(player, beatmap, replay, skin, post)
      when is_map(player) and is_map(beatmap) and is_binary(replay) and
             (is_map(skin) or is_nil(skin)) and (is_map(post) or is_nil(post)) do
    now = System.system_time(:millisecond)

    sql = """
    INSERT INTO #{@table} (player, beatmap, replay, skin, post, status, created_at, updated_at)
    VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
    """

    binds = [
      Jason.encode!(player),
      Jason.encode!(beatmap),
      replay,
      if(is_nil(skin), do: nil, else: Jason.encode!(skin)),
      if(is_nil(skin), do: nil, else: Jason.encode!(post)),
      @status.pending,
      now,
      now
    ]

    case DB.query(sql, bind: binds) do
      {:ok, _} ->
        case DB.query("SELECT LAST_INSERT_ROWID()") do
          {:ok, [%{"LAST_INSERT_ROWID()": id}]} ->
            %__MODULE__{
              id: id,
              player: player,
              beatmap: beatmap,
              replay: replay,
              skin: skin,
              post: post,
              status: @status.pending,
              created_at: now,
              updated_at: now
            }

          {:error, err} ->
            {:error, err}

          _ ->
            {:error, :no_id}
        end

      {:error, err} ->
        {:error, err}
    end
  end
end
