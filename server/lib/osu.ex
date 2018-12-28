defmodule OAAS.Osu do
  @moduledoc "osu!-related utility functions."

  use Bitwise, only_operators: true

  @doc "Defines the game mode enum."
  @spec mode(integer) :: binary
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
  @spec mods_to_string(integer) :: binary
  def mods_to_string(mods) do
    mods =
      @mods
      |> Enum.filter(fn {_m, v} -> (mods &&& v) === v end)
      |> Keyword.keys()

    mods = if(:NC in mods, do: List.delete(mods, :DT), else: mods)
    mods = if(:PF in mods, do: List.delete(mods, :SD), else: mods)

    if(Enum.empty?(mods), do: "", else: "+" <> Enum.join(mods, ","))
  end

  @doc "Converts a mod string into its numeric value."
  @spec mods_from_string(binary) :: non_neg_integer
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

  @doc "Computes the actual runtime of a beatmap, given its mods."
  @spec map_time(map, non_neg_integer) :: number
  def map_time(%{total_length: len}, mods) do
    dt = Keyword.get(@mods, :DT)
    ht = Keyword.get(@mods, :HT)

    cond do
      (mods &&& dt) === dt -> len / 1.5
      (mods &&& ht) === ht -> len * 1.5
      true -> len
    end
  end

  @doc "Converts a replay into its accuracy, in percent."
  @spec accuracy(map) :: float | nil
  def accuracy(%{mode: 0} = replay) do
    100.0 * (300 * replay.n300 + 100 * replay.n100 + 50 * replay.n50) /
      (300 * replay.n300 + 300 * replay.n100 + 300 * replay.n50 + 300 * replay.nmiss)
  end

  def accuracy(_replay) do
    nil
  end

  @skins_api "https://circle-people.com/skins-api.php?player="
  @default_skin %{
    name: "CirclePeople Default 2017-08-16",
    url:
      "https://circle-people.com/wp-content/Skins/Default Skins/CirclePeople Default 2017-08-16.osk"
  }

  @doc "Gets a player's skin."
  @spec skin(binary) :: map
  def skin(username) do
    case HTTPoison.get(@skins_api <> username) do
      {:ok, %{body: body}} ->
        if body === "" do
          if(username === "Default Skins", do: @default_skin, else: skin("Default Skins"))
        else
          name =
            body
            |> String.split("/")
            |> List.last()
            |> String.trim_trailing(".osk")

          %{name: name, url: body}
        end

      {:error, _reason} ->
        if(username === "Default Skins", do: @default_skin, else: skin("Default Skins"))
    end
  end

  @doc "Gets pp for a play."
  @spec pp(map, map, map) :: {:ok, number} | {:error, term}
  def pp(player, beatmap, replay) do
    case OsuEx.API.get_scores(beatmap.beatmap_id,
           u: player.user_id,
           m: replay.mode,
           mods: replay.mods
         ) do
      {:ok, [%{pp: pp}]} when is_number(pp) -> {:ok, pp + 0.0}
      {:ok, _scores} -> {:error, :score_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @downloader Application.get_env(:oaas, :osr_downloader)

  @doc "Downloads a .osr replay file."
  @spec get_osr(map, map, non_neg_integer | nil) ::
          {:ok, binary} | {:error, {:exit_code, integer}}
  def get_osr(%{user_id: user}, %{beatmap_id: beatmap}, mods) do
    args =
      ([@downloader, "-k", Application.get_env(:osu_ex, :api_key), "-u", user, "-b", beatmap] ++
         if(is_nil(mods), do: [], else: ["--mods", mods]))
      |> Enum.map(&to_string/1)

    case System.cmd(@downloader, args) do
      {osr, 0} -> {:ok, osr}
      {_, n} -> {:error, {:exit_code, n}}
    end
  end
end
