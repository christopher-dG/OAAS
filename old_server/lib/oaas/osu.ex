defmodule OAAS.Osu do
  @moduledoc "osu!-related utility functions."

  import OAAS.Utils
  use Bitwise, only_operators: true

  @doc "Defines the game mode enum."
  @spec mode(integer) :: String.t()
  def mode(0), do: "osu!"
  def mode(1), do: "osu!taiko"
  def mode(2), do: "osu!catch"
  def mode(3), do: "osu!mania"

  # This list is sorted in presentation order.
  @mods [
    EZ: 1 <<< 1,
    HD: 1 <<< 3,
    HT: 1 <<< 8,
    DT: 1 <<< 6,
    NC: 1 <<< 6 ||| 1 <<< 9,
    HR: 1 <<< 4,
    FL: 1 <<< 10,
    NF: 1 <<< 0,
    SD: 1 <<< 5,
    PF: 1 <<< 5 ||| 1 <<< 14,
    RX: 1 <<< 7,
    AP: 1 <<< 13,
    SO: 1 <<< 12,
    AT: 1 <<< 11,
    V2: 1 <<< 29,
    TD: 1 <<< 2
  ]

  @doc "Converts numeric mods to a string, e.g. 24 -> +HDHR"
  @spec mods_to_string(integer) :: String.t()
  def mods_to_string(mods) do
    mods =
      @mods
      |> Enum.filter(fn {_m, v} -> (mods &&& v) === v end)
      |> Keyword.keys()

    mods = if :NC in mods, do: List.delete(mods, :DT), else: mods
    mods = if :PF in mods, do: List.delete(mods, :SD), else: mods

    if Enum.empty?(mods), do: "", else: "+" <> Enum.join(mods, ",")
  end

  @doc "Converts a mod string into its numeric value."
  @spec mods_from_string(String.t()) :: integer
  def mods_from_string(mods) do
    mods
    |> String.replace(",", "")
    |> String.to_charlist()
    |> Enum.chunk_every(2)
    |> Enum.map(&to_string/1)
    |> Enum.reduce(0, fn mod, acc ->
      acc + Keyword.get(@mods, String.to_atom(mod), 0)
    end)
  end

  @doc "Converts a replay into its accuracy, in percent."
  @spec accuracy(map) :: float
  def accuracy(%{mode: 0} = r) do
    100.0 * (r.n300 + r.n100 / 3 + r.n50 / 6) / (r.n300 + r.n100 + r.n50 + r.nmiss)
  end

  def accuracy(%{mode: 1} = r) do
    100.0 * (r.n300 + r.n100 / 2) / (r.n300 + r.n100 + r.nmiss)
  end

  def accuracy(%{mode: 2} = r) do
    100.0 * (r.n300 + r.n100 + r.n50) / (r.n300 + r.n100 + r.n50 + r.nkatu + r.nmiss)
  end

  def accuracy(%{mode: 3} = r) do
    100.0 * (r.countgeki + r.count300 + 2 * r.nkatu / 3 + r.n100 / 3 + r.n50 / 6) /
      (r.ngeki + r.n300 + r.nkatu + r.n100 + r.n50 + r.nmiss)
  end

  @skins_api "https://circle-people.com/skins-api.php?player="
  @default_skin %{
    name: "CirclePeople Default 2017-08-16",
    url:
      "https://circle-people.com/wp-content/Skins/Default Skins/CirclePeople Default 2017-08-16.osk"
  }

  @doc "Gets a player's skin."
  @spec skin(String.t()) :: map
  def skin(username) do
    case HTTPoison.get(@skins_api <> username) do
      {:ok, %{body: body}} ->
        if body === "" do
          if username === "Default Skins", do: @default_skin, else: skin("Default Skins")
        else
          name =
            body
            |> String.split("/")
            |> List.last()
            |> String.trim_trailing(".osk")

          %{name: name, url: body}
        end

      {:error, _reason} ->
        if username === "Default Skins", do: @default_skin, else: skin("Default Skins")
    end
  end

  @doc "Gets pp for a play."
  @spec pp(map, map, map) :: {:ok, float} | {:error, term}
  def pp(player, beatmap, replay) do
    case OsuEx.API.get_scores(beatmap.beatmap_id,
           u: player.user_id,
           m: replay.mode,
           mods: replay.mods
         ) do
      {:ok, [%{pp: pp}]} when is_number(pp) -> {:ok, pp + 0.0}
      {:ok, []} -> {:error, :score_not_found}
      {:ok, [_score]} -> {:error, :no_pp}
      {:error, reason} -> {:error, reason}
    end
  end

  @ho_time_type_re ~r/.*?,.*?,(.*?),(.*?),/
  @tp_duration_re ~r/.*?,(.*?),/
  @dt Keyword.get(@mods, :DT)
  @ht Keyword.get(@mods, :HT)

  @doc "Gets the milliseconds from beginning of first object to end of last."
  @spec replay_length(map, integer) :: integer
  def replay_length(%{beatmap_id: beatmap_id, total_length: total_length}, mods \\ 0) do
    len =
      try do
        %{status_code: 200, body: osu} = HTTPoison.get!("https://osu.ppy.sh/osu/#{beatmap_id}")

        lines =
          osu
          |> String.split("\n")
          |> Enum.reject(&(String.trim(&1) == ""))

        hos_start = Enum.find_index(lines, &String.contains?(&1, "[HitObjects]")) + 1
        hos = Enum.slice(lines, hos_start..length(lines))
        hos_end = (Enum.find_index(hos, &String.contains?(&1, "[")) || length(hos)) - 1
        first_ho = hd(hos)
        last_ho = Enum.at(hos, hos_end)
        start_ms = first_match_float!(@ho_time_type_re, first_ho)

        [_, last_start, last_type] = Regex.run(@ho_time_type_re, last_ho)
        last_start = parse_float!(last_start)

        last_type =
          last_type
          |> parse_float!()
          |> round()

        last_end =
          cond do
            (last_type &&& 1) == 1 ->
              # Circle: Ends when it starts.
              last_start

            (last_type &&& 2) == 2 ->
              # Slider: Depends on a few beatmap variables, timing points, and the slider length.
              tps_start = Enum.find_index(lines, &String.contains?(&1, "[TimingPoints]")) + 1
              first_tp = Enum.at(lines, tps_start)
              base_duration = first_match_float!(@tp_duration_re, first_tp)
              tps = Enum.slice(lines, tps_start..length(lines))

              last_tp =
                Enum.reduce_while(tps, first_tp, fn tp, acc ->
                  if String.contains?(tp, "[") do
                    {:halt, acc}
                  else
                    case first_match_float!(~r/(.*?),/, tp) do
                      n when n > last_start -> {:halt, acc}
                      _ -> {:cont, tp}
                    end
                  end
                end)

              last_duration =
                case first_match_float!(~r/.*?,(.*?),/, last_tp) do
                  n when n >= 0 -> n
                  n -> base_duration * abs(n) / 100
                end

              pixel_length = first_match_float!(~r/(?:.*?,){7}([^,]+)/, last_ho)

              slider_multiplier =
                case Regex.run(~r/SliderMultiplier:(.*)/, osu) do
                  [_, n] -> parse_float!(n)
                  nil -> 1.4
                end

              last_start + pixel_length / (100 * slider_multiplier) * last_duration

            (last_type &&& 8) == 8 ->
              # Spinner: Has an end time component.
              first_match_float!(~r/(?:.*?,){5}([^,]+)/, last_ho)
          end

        last_end - start_ms
      rescue
        reason ->
          notify(:warn, "Getting exact beatmap length failed.", reason)
          total_length * 1000
      end

    len =
      cond do
        (mods &&& @dt) === @dt ->
          notify(:debug, "Applied DT length reduction.")
          len / 1.5

        (mods &&& @ht) === @ht ->
          notify(:debug, "Applied HT length increase.")
          len * 1.5

        true ->
          notify(:debug, "No length-modifying mods.")
          len
      end

    round(len)
  end

  # Parse a float that is known to be valid.
  @spec parse_float!(String.t()) :: float
  defp parse_float!(s) do
    {n, ""} =
      s
      |> String.trim()
      |> Float.parse()

    n
  end

  # Extract a float with a regex.
  @spec first_match_float!(Regex.t(), String.t()) :: float
  defp first_match_float!(regex, string) do
    regex
    |> Regex.run(string)
    |> Enum.at(1)
    |> parse_float!()
  end
end
