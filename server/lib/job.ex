defmodule ReplayFarm.Job do
  @moduledoc "Jobs are recording/uploading tasks to be completed."

  alias OsuEx.API, as: OsuAPI
  alias OsuEx.Parser
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
  @enforce_keys [:id, :player, :beatmap, :replay, :youtube, :status, :created_at, :updated_at]
  defstruct @enforce_keys ++ [:skin, :comment, :worker_id]

  @type t :: %__MODULE__{
          # Job ID.
          id: integer,
          # Player data: {id, name}.
          player: map,
          # Beatmap data: {id, name, mode}.
          beatmap: map,
          # The .osr file, as base64.
          replay: binary,
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

  @json_columns [:player, :beatmap, :youtube, :skin]

  use ReplayFarm.Model

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

  # It gets pretty ugly from here on down.

  # def from_reddit(data) when is_map(data) do
  # end

  # Create a recording job from a replay link.
  @spec from_osr!(binary) :: t
  def from_osr!(url) when is_binary(url) do
    %{body: osr} = HTTPoison.get!(url)
    replay = Parser.osr!(osr)
    player = OsuAPI.get_user!(replay.player)
    beatmap = OsuAPI.get_beatmap!(replay.beatmap_md5)
    playerskin = skin(player.username)
    yt = ytdata(player, beatmap, replay) |> IO.inspect()

    put!(
      player: player,
      beatmap: beatmap,
      replay: Base.encode64(osr),
      youtube: yt,
      skin: playerskin,
      status: status(:pending)
    )
  end

  @skins_api "https://circle-people.com/skins-api.php?player="

  # Get a player's skin.
  @spec skin(binary) :: map | nil
  def skin(username) when is_binary(username) do
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

  # Convert numeric mods to a string, e.g. 25 -> +HDHR.
  @spec modstring(integer) :: binary | nil
  defp modstring(0), do: nil

  defp modstring(mods) when is_integer(mods) do
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
  defp ppstring(beatmap, mode, mods, acc)
       when is_map(beatmap) and is_integer(mode) and is_integer(mods) and is_number(acc) do
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
  def ytdata(player, beatmap, replay)
      when is_map(player) and is_map(beatmap) and is_map(replay) do
    mods = modstring(replay.mods)
    percent = acc(replay)
    acc_s = if(is_nil(percent), do: nil, else: :erlang.float_to_binary(percent, decimals: 2) <> "%")
    fc = if(replay.perfect?, do: "FC", else: nil)
    pp = ppstring(beatmap, replay.mode, replay.mods, percent)
    extra = [mods, acc_s, fc, pp] |> Enum.reject(&is_nil/1) |> Enum.join(" ")

    title =
      "#{@modes[replay.mode]} | #{player.username} | #{beatmap.artist} - #{beatmap.title} [#{
        beatmap.version
      }] #{extra}"

    desc = title <> "\n" <> description(player, beatmap)
    %{title: title, description: desc}
  end
end
