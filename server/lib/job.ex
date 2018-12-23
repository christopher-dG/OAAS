defmodule ReplayFarm.Job do
  @moduledoc "Jobs are recording/uploading tasks to be completed."

  use Bitwise, only_operators: true

  alias ReplayFarm.DB
  alias ReplayFarm.Worker
  import ReplayFarm.Utils
  require DB

  @doc "Defines the job status enum."
  def status(_s)

  @spec status(atom) :: integer
  def status(:pending), do: 0
  def status(:assigned), do: 1
  def status(:recording), do: 2
  def status(:uploading), do: 3
  def status(:successful), do: 4
  def status(:failed), do: 5
  def status(:deleted), do: 6

  @spec status(integer) :: atom
  def status(0), do: :pending
  def status(1), do: :assigned
  def status(2), do: :recording
  def status(3), do: :uploading
  def status(4), do: :successful
  def status(5), do: :failed
  def status(6), do: :deleted

  @table "jobs"

  @derive Jason.Encoder
  @enforce_keys [:id, :player, :beatmap, :replay, :youtube, :status, :created_at, :updated_at]
  defstruct @enforce_keys ++ [:skin, :comment, :worker_id]

  @type t :: %__MODULE__{
          # Job ID.
          id: integer,
          # Player data: {id, name}.
          player: map,
          # Beatmap data: {id, name, mode}.
          beatmap: map,
          # Replay data: {data, length}.
          replay: map,
          # YouTube upload data: {title, description}.
          youtube: map,
          # Skin to use: {name, url} (nil means default).
          skin: map | nil,
          # Job status.
          status: integer,
          # Comment from the worker.
          comment: binary | nil,
          # Assigned worker.
          worker_id: binary | nil,
          # Job creation time.
          created_at: integer,
          # Job update time.
          updated_at: integer
        }

  @json_columns [:player, :beatmap, :replay, :youtube, :skin]

  use ReplayFarm.Model

  @doc "Deletes ajob."
  @spec delete(t) :: {:ok, t} | {:error, term}
  def delete(%__MODULE__{} = j) do
    update(j, status: status(:deleted))
  end

  @timeouts %{
    assigned: 90 * 1000,
    recording: 10 * 60 * 1000,
    uploading: 10 * 60 * 1000
  }

  @doc "Gets all jobs which are running but stalled."
  @spec get_stalled :: [t]
  def get_stalled do
    now = System.system_time(:millisecond)

    case query(
           "SELECT * FROM #{@table} WHERE status BETWEEN ?1 AND ?2",
           x: status(:assigned),
           x: status(:uploading)
         ) do
      {:ok, js} ->
        {:ok, Enum.filter(js, fn j -> abs(now - j.updated_at) > @timeouts[status(j.status)] end)}

      {:error, err} ->
        {:error, err}
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
    query("SELECT * FROM #{@table} WHERE status = ?1", x: stat)
  end

  @doc "Assigns a job to a worker."
  @spec assign(t, Worker.t()) :: {:ok, t} | {:error, term}
  def assign(%__MODULE__{} = j, %Worker{} = w) do
    DB.transaction do
      with {:ok, _} <-
             Worker.update(w, current_job_id: j.id, last_job: System.system_time(:millisecond)),
           {:ok, j} <- update(j, worker_id: w.id, status: status(:assigned)) do
        {:ok, j}
      else
        {:error, err} -> {:error, err}
      end
    end
  end

  @doc "Checks whether a job is finished."
  @spec finished(t) :: boolean
  def finished(%__MODULE__{} = j) do
    j.status >= status(:successful)
  end

  @doc "Updates a job's status."
  @spec update_status(t, Worker.t(), integer, binary) :: {:ok, t} | {:error, term}
  def update_status(%__MODULE__{} = j, %Worker{} = w, stat, comment) do
    DB.transaction do
      case update(j, status: stat, comment: comment) do
        {:ok, j} ->
          if finished(j) do
            case Worker.update(w, current_job_id: nil) do
              {:ok, _w} -> {:ok, j}
              {:error, err} -> {:error, err}
            end
          else
            {:ok, j}
          end

        {:error, err} ->
          {:error, err}
      end
    end
  end

  @doc "Fails a job."
  @spec fail(t, binary) :: {:ok, t} | {:error, term}
  def fail(%__MODULE__{} = j, comment \\ "") do
    DB.transaction do
      with {:ok, %Worker{} = w} <- Worker.get(j.worker_id),
           {:ok, _w} <- Worker.update(w, current_job_id: nil),
           {:ok, j} <- update(j, worker_id: nil, status: status(:failed), comment: comment) do
        {:ok, j}
      else
        {:error, err} -> {:error, err}
      end
    end
  end

  @doc "Reschedules a job."
  @spec reschedule(t) :: {:ok, t} | {:error, term}
  def reschedule(%__MODULE__{} = j) do
    unless j.status === status(:failed) do
      notify(:warn, "rescheduling non-failed job #{j.id} (#{status(j.status)})")
    end

    update(j, status: status(:pending), comment: "rescheduled")
  end

  @doc "Creates a job from a Reddit post."
  @spec from_reddit(map) :: {:ok, t} | {:error, term}
  def from_reddit(_data) do
    {:error, :todo}
  end

  @doc "Creates a job from a replay link."
  @spec from_osr(binary) :: {:ok, t} | {:error, term}
  def from_osr(url) do
    with {:ok, %{body: osr}} <- HTTPoison.get(url),
         {:ok, replay} = OsuEx.Parser.osr(osr),
         {:ok, player} = OsuEx.API.get_user(replay.player),
         {:ok, beatmap} = OsuEx.API.get_beatmap(replay.beatmap_md5) do
      put(
        player: player,
        beatmap: beatmap,
        replay: %{data: Base.encode64(osr), length: replaytime(beatmap, replay.mods)},
        youtube: ytdata(player, beatmap, replay),
        skin: skin(player.username),
        status: status(:pending)
      )
    else
      {:error, err} -> {:error, err}
    end
  end

  @skins_api "https://circle-people.com/skins-api.php?player="

  # Get a player's skin.
  @spec skin(binary) :: map | nil
  def skin(username) do
    case HTTPoison.get(@skins_api <> username) do
      {:ok, resp} ->
        if resp.body === "" do
          notify("no skin available for user `#{username}`")
          nil
        else
          %{
            name: resp.body |> String.split("/") |> List.last() |> String.trim_trailing(".osk"),
            url: resp.body
          }
        end

      {:error, err} ->
        notify(:warn, "couldn't get skin for user `#{username}`", err)
        nil
    end
  end

  @dt 64
  @ht 256

  # Compute the actual runtime of a replay, given its mods.
  @spec replaytime(map, integer) :: number
  defp replaytime(%{total_length: len}, mods) do
    cond do
      (mods &&& @dt) === @dt -> len / 1.5
      (mods &&& @ht) === @ht -> len * 1.5
      true -> len
    end
  end

  # Convert numeric mods to a string, e.g. 25 -> +HDHR.
  @spec modstring(integer) :: binary | nil
  defp modstring(0) do
    nil
  end

  defp modstring(_mods) do
    # TODO
    nil
  end

  # Convert a replay into its accuracy, in percent.
  @spec acc(map) :: float | nil
  defp acc(%{mode: 0} = replay) do
    100.0 * (300 * replay.n300 + 100 * replay.n100 + 50 * replay.n50) /
      (300 * replay.n300 + 300 * replay.n100 + 300 * replay.n50 + 300 * replay.nmiss)
  end

  defp acc(_replay), do: nil

  # Calculate pp for a play.
  @spec ppstring(map, integer, integer, number) :: binary | nil
  defp ppstring(_beatmap, _mode, _mods, _acc) do
    # TODO
    nil
  end

  # Generate the YouTube description.
  @spec description(map, map) :: binary
  defp description(%{username: username, user_id: user_id}, %{beatmap_id: beatmap_id}) do
    """
    #{username}'s Profile: https://osu.ppy.sh/u/#{user_id} | #{username}'s Skin: https://circle-people.com/skins | Map: https://osu.ppy.sh/b/#{
      beatmap_id
    } | Click "Show more" for an explanation what this video and free to play rhythm game is all about!

    ------------------------------------------------------

    osu! is the perfect game if you're looking for ftp games as osu! is a free to play online rhythm game, which you can use as a rhythm trainer online with lots of gameplay music!
    https://osu.ppy.sh
    osu! has online rankings, multiplayer and boasts a community with over 500,000 active users!

    Title explanation:
    PlayerName | Artist - Song [Difficulty] +ModificationOfMap | PlayerAccuracyOnMap% PointsAwardedForThisPlayPP

    Want to support what we do? Check out our Patreon!
    https://www.patreon.com/circlepeople

    Join the CirclePeople community! https://discord.gg/CirclePeople
    Don't want to miss any pro plays? Subscribe or follow us!
    Twitter: https://twitter.com/CirclePeopleYT
    Facebook: https://facebook.com/CirclePeople

    Want some sweet custom covers for your tablet?
    https://yangu.pw/shop - Order here!

    #CirclePeople
    #osu
    ##{username}
    """
  end

  @modes %{0 => "osu!", 1 => "osu!taiko", 2 => "osu!catch", 3 => "osu!mania"}

  @doc "Gets YouTube upload data for a play."
  @spec ytdata(map, map, map) :: map
  def ytdata(player, beatmap, replay) do
    mods = modstring(replay.mods)
    fc = if(replay.perfect?, do: "FC", else: nil)
    percent = acc(replay)
    pp = ppstring(beatmap, replay.mode, replay.mods, percent)

    acc_s =
      if is_nil(percent) do
        nil
      else
        :erlang.float_to_binary(percent, decimals: 2) <> "%"
      end

    extra =
      [mods, acc_s, fc, pp]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")

    title =
      "#{@modes[replay.mode]} | #{player.username} | #{beatmap.artist} - #{beatmap.title} [#{
        beatmap.version
      }] #{extra}"

    desc = title <> "\n" <> description(player, beatmap)
    %{title: title, description: desc}
  end
end
