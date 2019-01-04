defmodule OAAS.Job.Replay do
  @moduledoc "A replay recording/uploading job."

  alias OAAS.Osu
  alias OAAS.Job
  import OAAS.Utils
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
          replay: %{osr: String.t(), length: float},
          youtube: %{title: String.t(), description: String.t()},
          skin: %{name: String.t(), url: String.t()},
          reddit_id: String.t() | nil
        }

  @doc "Describes a job."
  @spec describe(Job.t()) :: String.t()
  def describe(j) do
    player = "#{j.data.player.username} (https://osu.ppy.sh/u/#{j.data.player.user_id})"
    reddit = if(is_nil(j.data.reddit_id), do: "None", else: "https://redd.it/#{j.data.reddit_id}")

    beatmap =
      "#{j.data.beatmap.artist} - #{j.data.beatmap.title} [#{j.data.beatmap.version}] (https://osu.ppy.sh/b/#{
        j.data.beatmap.beatmap_id
      })"

    """
    ```yml
    #{Job.describe(j)}
    Player: #{player}
    Beatmap: #{beatmap}
    Video: #{j.data.youtube.title}
    Skin: #{(j.data.skin || %{})[:name] || "None"}
    Reddit: #{reddit}
    Replay:
      Date: #{j.data.replay.timestamp}
      Mods: #{Osu.mods_to_string(j.data.replay.mods)}
      Combo: #{j.data.replay.combo}
      Score: #{j.data.replay.score}
      Accuracy: #{j.data.replay |> Osu.accuracy() |> :erlang.float_to_binary(decimals: 2)}%
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
      skin = Osu.skin(player.username)

      Job.put(
        type: Job.type(__MODULE__),
        status: Job.status(:pending),
        data: %__MODULE__{
          player: Map.drop(player, [:events]),
          beatmap: beatmap,
          replay:
            Map.merge(replay, %{
              replay_data: nil,
              osr: Base.encode64(osr),
              length: Osu.map_time(beatmap, replay.mods)
            }),
          youtube: youtube_data(player, beatmap, replay, skin),
          skin: skin,
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
      skin = Osu.skin(skin_override || player.username)

      Job.put(
        type: Job.type(__MODULE__),
        status: Job.status(:pending),
        data: %__MODULE__{
          player: Map.drop(player, [:events]),
          beatmap: beatmap,
          replay:
            Map.merge(replay, %{
              osr: Base.encode64(osr),
              length: Osu.map_time(beatmap, replay.mods)
            }),
          youtube: youtube_data(player, beatmap, replay, skin),
          skin: skin
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
        :erlang.float_to_binary(pp, decimals: 0) <> "pp"

      {:error, reason} ->
        notify(:warn, "Looking up score for pp value failed.", reason)
        nil
    end
  end

  # Generate the YouTube description.
  @spec description(map, map, map) :: String.t()
  defp description(%{username: name, user_id: user_id}, %{beatmap_id: beatmap_id}, %{name: skin}) do
    skin_name =
      if String.starts_with?(skin, "CirclePeople") do
        "Default Skin"
      else
        "#{name}'s Skin"
      end

    """
    #{name}'s Profile: https://osu.ppy.sh/u/#{user_id} | #{skin_name}'s Skin: https://circle-people.com/skins
    Map: https://osu.ppy.sh/b/#{beatmap_id} | Click "Show more" for an explanation what this video and free to play rhythm game is all about!

    ------------------------------------------------------
    osu! is the perfect game if you're looking for ftp games as
    osu! is a free to play online rhythm game, which you can use as a rhythm trainer online with lots of gameplay music!
    https://osu.ppy.sh
    osu! has online rankings, multiplayer and boasts a community with over 500,000 active users!

    Title explanation:
    PlayerName | Artist - Song [Difficulty] +ModificationOfMap PlayerAccuracyOnMap% PointsAwardedForThisPlayPP

    Want to support what we do? Check out our Patreon!
    https://patreon.com/CirclePeople

    Join the CirclePeople community!
    https://discord.gg/CirclePeople
    Don't want to miss any pro plays? Subscribe or follow us!
    Twitter: https://twitter.com/CirclePeopleYT
    Facebook: https://facebook.com/CirclePeople

    Want some sweet custom covers for your tablet?
    https://yangu.pw/shop - Order here!

    #CirclePeople
    #osu
    ##{name}
    """
  end

  @title_limit 100

  # Get YouTube upload data for a play.
  @spec youtube_data(map, map, map, map) :: map
  defp youtube_data(player, beatmap, replay, skin) do
    mods = Osu.mods_to_string(replay.mods)
    mods = if(mods === "", do: nil, else: mods)
    fc = if(replay.perfect?, do: "FC", else: nil)
    percent = :erlang.float_to_binary(Osu.accuracy(replay), decimals: 2) <> "%"
    pp = pp_string(player, beatmap, replay)

    extra =
      [mods, percent, fc, pp]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")

    map_name = "#{beatmap.artist} - #{beatmap.title} [#{beatmap.version}]"
    title = String.trim("#{Osu.mode(replay.mode)} | #{player.username} | #{map_name} #{extra}")

    notify(:debug, "Computed video title: #{title}.")
    yt_title = if(String.length(title) > @title_limit, do: "Placeholder Title", else: title)

    desc = title <> "\n" <> description(player, beatmap, skin)
    %{title: yt_title, description: desc}
  end

  # Get the player name from a post title.
  @spec extract_username(String.t()) :: {:ok, String.t()} | {:error, :no_player_match}
  defp extract_username(title) do
    case Regex.run(~r/(.+?)\|/, title) do
      [_, cap] ->
        username =
          cap
          |> (&Regex.replace(~r/\(.*?\)/, &1, "")).()
          |> String.trim()

        notify(:debug, "Extracted username '#{username}'.")
        {:ok, username}

      nil ->
        {:error, :no_player_match}
    end
  end

  # Get the beatmap name from a post title.
  @spec extract_map_name(String.t()) :: {:ok, String.t()} | {:error, :no_map_match}
  defp extract_map_name(title) do
    case Regex.run(~r/\|(.+?)-(.+?)\[(.+)\]/, title) do
      [_, artist, title, diff] ->
        s = "#{String.trim(artist)} - #{String.trim(title)} [#{String.trim(diff)}]"
        notify(:debug, "Extracted map name: '#{s}'.")
        {:ok, s}

      nil ->
        {:error, :no_map_match}
    end
  end

  # Get the mods (as a number) from a post title.
  @spec extract_mods(String.t()) :: {:ok, integer | nil}
  defp extract_mods(title) do
    {:ok,
     case Regex.run(~r/\+ ?([A-Z,]+)/, title) do
       [_, mods] ->
         notify(:debug, "Extracted mods: '+#{mods}'.")
         Osu.mods_from_string(mods)

       nil ->
         nil
     end}
  end

  # Look for a beatmap by name in a player's activity.
  @spec search_beatmap(map, binary) :: {:ok, map} | {:error, :beatmap_not_found}
  defp search_beatmap(player, map_name) do
    notify(:debug, "Searching for: '#{map_name}'.")
    map_name = String.downcase(map_name)

    try do
      case search_events(player, map_name) do
        {:ok, beatmap} -> throw(beatmap)
        _ -> :noop
      end

      case search_recent(player, map_name) do
        {:ok, beatmap} -> throw(beatmap)
        _ -> :noop
      end

      case search_best(player, map_name) do
        {:ok, beatmap} -> throw(beatmap)
        _ -> :noop
      end

      {:error, :beatmap_not_found}
    catch
      beatmap ->
        notify(:debug, "Found beatmap #{beatmap.beatmap_id}.")
        {:ok, beatmap}
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
    case OsuEx.API.get_user_recent(id, limit: 50) do
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
    scores
    |> Enum.uniq_by(&Map.get(&1, :beatmap_id))
    |> Enum.find_value({:error, :not_found}, fn %{beatmap_id: map_id} ->
      case OsuEx.API.get_beatmap(map_id) do
        {:ok, %{artist: artist, title: title, version: version} = beatmap} ->
          if strcmp("#{artist} - #{title} [#{version}]", map_name) do
            {:ok, beatmap}
          else
            false
          end

        _ ->
          false
      end
    end)
  end

  @osusearch_url "https://osusearch.com/api/search"
  @osusearch_key Application.get_env(:oaas, :osusearch_key)

  @spec search_osusearch(String.t()) :: {:ok, map} | {:error, :not_found}
  def search_osusearch(map_name) do
    [_, artist, title, diff] = Regex.run(~r/(.+?) - (.+?) \[(.+?)\]/, map_name)
    params = URI.encode_query(key: @osusearch_key, artist: artist, title: title, diff_name: diff)

    with {:ok, %{status_code: 200, body: body}} <- HTTPoison.get(@osusearch_url <> "?" <> params),
         {:ok, %{"beatmaps" => [_h | _t] = beatmaps}} <- Jason.decode(body) do
      beatmaps =
        beatmaps
        |> atom_map()
        |> Enum.filter(fn %{artist: a, title: t, difficulty_name: d} ->
          strcmp("#{a} - #{t} [#{d}]", map_name)
        end)

      if Enum.empty?(beatmaps) do
        {:error, :not_found}
      else
        beatmaps
        |> Enum.max_by(&Map.get(&1, :favorites), fn -> nil end)
        |> hd()
        |> Map.get(:beatmap_id)
        |> OsuEx.API.get_beatmap()
      end
    else
      _ -> {:error, :not_found}
    end
  end
end
