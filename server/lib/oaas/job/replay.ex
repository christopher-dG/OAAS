defmodule OAAS.Job.Replay do
  @moduledoc "Replay recording/uploading tasks to be completed."

  import OAAS.Utils
  alias OAAS.Osu
  alias OAAS.Job
  use Bitwise, only_operators: true

  @derive Jason.Encoder
  @enforce_keys [:player, :beatmap, :replay, :youtube, :skin]
  defstruct @enforce_keys ++ [:reddit_id]

  @type t :: %__MODULE__{
          player: %{user_id: integer, username: String.t()},
          beatmap: %{
            beatmap_id: integer,
            artist: String.t(),
            title: String.t(),
            version: String.t()
          },
          replay: %{replay_data: String.t(), length: float},
          youtube: %{title: String.t(), description: String.t()},
          skin: %{name: String.t(), url: String.t()},
          reddit_id: String.t() | nil
        }

  @doc "Describes the job."
  @spec describe(Job.t()) :: String.t()
  def describe(j) do
    player = "#{j.data.player.username} (https://osu.ppy.sh/u/#{j.data.player.user_id})"
    reddit = if(is_nil(j.data.reddit_id), do: "none", else: "https://redd.it/#{j.data.reddit_id}")

    beatmap =
      "#{j.data.beatmap.artist} - #{j.data.beatmap.title} [#{j.data.beatmap.version}] (https://osu.ppy.sh/b/#{
        j.data.beatmap.beatmap_id
      })"

    """
    ```yml
    id: #{j.id}
    worker: #{j.worker_id || "none"}
    status: #{Job.status(j.status)}
    comment: #{j.comment || "none"}
    created: #{relative_time(j.created_at)}
    updated: #{relative_time(j.updated_at)}
    player: #{player}
    beatmap: #{beatmap}
    video: #{j.data.youtube.title}
    skin: #{(j.data.skin || %{})[:name] || "none"}
    reddit: #{reddit}
    replay:
      mods: #{Osu.mods_to_string(j.data.replay.mods)}
      combo: #{j.data.replay.combo}
      score: #{j.data.replay.score}
      accuracy: #{Osu.accuracy(j.data.replay)}
    ```
    """
  end

  @doc "Creates a replay job from a Reddit post."
  @spec from_reddit(String.t(), String.t()) :: {:ok, Job.t()} | {:error, term}
  def from_reddit(id, title) do
    with {:ok, username} <- extract_username(title),
         {:ok, map_name} <- extract_map_name(title),
         {:ok, mods} <- extract_mods(title),
         {:ok, %{} = player} <- OsuEx.API.get_user(username, event_days: 31),
         {:ok, %{} = beatmap} <- search_beatmap(player, map_name),
         {:ok, osr} <- Osu.get_osr(player, beatmap, mods),
         {:ok, replay} <- OsuEx.Parser.osr(osr) do
      Job.put(
        type: Job.type(__MODULE__),
        status: Job.status(:pending),
        data: %__MODULE__{
          player: Map.drop(player, [:events]),
          beatmap: beatmap,
          replay:
            Map.merge(replay, %{
              replay_data: Base.encode64(osr),
              length: Osu.map_time(beatmap, replay.mods)
            }),
          youtube: youtube_data(player, beatmap, replay),
          skin: Osu.skin(player.username),
          reddit_id: id
        }
      )
    else
      {:ok, nil} -> {:error, :player_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Creates a replay job from a replay link."
  @spec from_osr(String.t(), String.t() | nil) :: {:ok, Job.t()} | {:error, term}
  def from_osr(url, skin_override \\ nil) do
    with {:ok, %{body: osr}} <- HTTPoison.get(url),
         {:ok, replay} = OsuEx.Parser.osr(osr),
         {:ok, player} = OsuEx.API.get_user(replay.player),
         {:ok, beatmap} = OsuEx.API.get_beatmap(replay.beatmap_md5) do
      Job.put(
        type: Job.type(__MODULE__),
        status: Job.status(:pending),
        data: %__MODULE__{
          player: Map.drop(player, [:events]),
          beatmap: beatmap,
          replay:
            Map.merge(replay, %{
              replay_data: Base.encode64(osr),
              length: Osu.map_time(beatmap, replay.mods)
            }),
          youtube: youtube_data(player, beatmap, replay),
          skin: Osu.skin(skin_override || player.username)
        }
      )
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Get pp for a play as a string.
  @spec pp_string(map, map, map) :: String.t() | nil
  defp pp_string(player, beatmap, replay) do
    case Osu.pp(player, beatmap, replay) do
      {:ok, pp} ->
        :erlang.float_to_binary(pp, decimals: 2) <> "pp"

      {:error, reason} ->
        notify(:warn, "looking up score failed", reason)
        nil
    end
  end

  # Generate the YouTube description.
  @spec description(map, map) :: String.t()
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
    GameMode | PlayerName | Artist - Song [Difficulty] +ModificationOfMap | PlayerAccuracyOnMap% PointsAwardedForThisPlayPP

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

  @title_limit 100

  # Get YouTube upload data for a play.
  @spec youtube_data(map, map, map) :: map
  defp youtube_data(player, beatmap, replay) do
    mods = Osu.mods_to_string(replay.mods)
    mods = if(mods === "", do: nil, else: mods)
    fc = if(replay.perfect?, do: "FC", else: nil)
    percent = Osu.accuracy(replay)
    pp = pp_string(player, beatmap, replay)

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
      "#{Osu.mode(replay.mode)} | #{player.username} | #{beatmap.artist} - #{beatmap.title} [#{
        beatmap.version
      }] #{extra}"

    yt_title = if(String.length(title) > @title_limit, do: "Placeholder Title", else: title)

    desc = title <> "\n" <> description(player, beatmap)
    %{title: yt_title, description: desc}
  end

  # Get the player name from a post title.
  @spec extract_username(String.t()) :: {:ok, String.t()} | {:error, :no_player_match}
  defp extract_username(title) do
    case Regex.run(~r/(.+?)\|/, title, capture: :all_but_first) do
      [cap] ->
        {:ok,
         cap
         |> (&Regex.replace(~r/\(.*?\)/, &1, "")).()
         |> String.trim()}

      nil ->
        {:error, :no_player_match}
    end
  end

  # Get the beatmap name from a post title.
  @spec extract_map_name(String.t()) :: {:ok, String.t()} | {:error, :no_map_match}
  defp extract_map_name(title) do
    case Regex.run(~r/\|(.+?)-(.+?)\[(.+?)\]/, title, capture: :all_but_first) do
      [artist, title, diff] ->
        {:ok, "#{String.trim(artist)} - #{String.trim(title)} [#{String.trim(diff)}]"}

      nil ->
        {:error, :no_map_match}
    end
  end

  # Get the mods (as a number) from a post title.
  @spec extract_mods(String.t()) :: {:ok, integer | nil}
  defp extract_mods(title) do
    {:ok,
     case Regex.run(~r/\+ ?([A-Z,]+)/, title, capture: :all_but_first) do
       [mods] -> Osu.mods_from_string(mods)
       nil -> nil
     end}
  end

  # Look for a beatmap by name in a player's activity.
  @spec search_beatmap(map, binary) :: {:ok, map} | {:error, :beatmap_not_found}
  defp search_beatmap(player, map_name) do
    notify(:debug, "searching for: #{map_name}")
    map_name = String.downcase(map_name)

    try do
      case search_events(player, map_name) do
        {:ok, beatmap} -> throw(beatmap)
        _ -> nil
      end

      case search_recent(player, map_name) do
        {:ok, beatmap} -> throw(beatmap)
        _ -> nil
      end

      case search_best(player, map_name) do
        {:ok, beatmap} -> throw(beatmap)
        _ -> nil
      end

      {:error, :beatmap_not_found}
    catch
      beatmap -> {:ok, beatmap}
    end
  end

  # Search a player's recent events for a beatmap.
  @spec search_events(map, String.t()) :: {:ok, map} | {:error, term}
  defp search_events(%{events: events}, map_name) do
    case Enum.find(events, fn %{display_html: html} ->
           html
           |> String.downcase()
           |> String.contains?(map_name)
         end) do
      %{beatmap_id: id} -> OsuEx.API.get_beatmap(id)
      _ -> {:error, nil}
    end
  end

  # Search a player's recent plays for a beatmap.
  @spec search_recent(%{user_id: non_neg_integer}, String.t()) :: {:ok, map} | {:error, term}
  defp search_recent(%{user_id: id}, map_name) do
    case OsuEx.API.get_user_recent(id) do
      {:ok, scores} -> search_scores(scores, map_name)
      {:error, reason} -> {:error, reason}
    end
  end

  # Search a player's best plays for a beatmap.
  @spec search_best(map, String.t()) :: {:ok, map} | {:error, term}
  defp search_best(%{user_id: id}, map_name) do
    case OsuEx.API.get_user_best(id, limit: 100) do
      {:ok, scores} -> search_scores(scores, map_name)
      {:error, reason} -> {:error, reason}
    end
  end

  # Search a list of scores for a beatmap.
  @spec search_scores([map], String.t()) :: {:ok, map} | {:error, :not_found}
  defp search_scores(scores, map_name) do
    Enum.find_value(scores, {:error, :not_found}, fn %{beatmap_id: map_id} ->
      case OsuEx.API.get_beatmap(map_id) do
        {:ok, %{artist: artist, title: title, version: version} = beatmap} ->
          if String.downcase("#{artist} - #{title} [#{version}]") === map_name do
            {:ok, beatmap}
          else
            false
          end

        _ ->
          false
      end
    end)
  end
end
