defmodule ReplayFarm.Discord.Command do
  @moduledoc "Command parsing and execution."

  require Logger

  alias ReplayFarm.Discord.Utils
  alias ReplayFarm.Job

  @doc "Parses a command."
  @spec parse([binary]) :: map | nil
  def parse(_list)

  def parse(["new" | args]) do
    Enum.reduce(args, %{command: :new}, fn token, acc ->
      case token do
        "https://" <> _ = replay -> Map.put(acc, :replay, replay)
        beatmap -> Map.put(acc, :beatmap, beatmap)
      end
    end)
  end

  def parse([cmd | args]) do
    Logger.info("received unknown command #{cmd} with args #{Enum.join(args, ", ")}")
    nil
  end

  @doc "Validates a command."
  @spec validate(map | nil) :: map | nil
  def validate(_cmd)

  def validate(%{command: :new} = cmd) do
    cond do
      is_nil(cmd[:beatmap]) ->
        Utils.send_message("Command `new` is missing beatmap.")
        nil

      is_nil(cmd[:replay]) ->
        Utils.send_message("Command `new` is missing replay.")
        nil

      true ->
        case Integer.parse(cmd.beatmap) do
          {b, ""} -> Map.put(cmd, :beatmap, b)
          _ -> Utils.send_message("Beatmap `#{cmd.beatmap}` is not a valid ID.") && nil
        end
    end
  end

  def validate(nil) do
    nil
  end

  @doc "Executes a command."
  @spec exec(map | nil) :: no_return
  def exec(cmd) do
    try do
      exec!(cmd)
    rescue
      e ->
        Utils.send_message("Execution failed: `#{Exception.message(e)}`") &&
          IO.inspect(__STACKTRACE__)
    end
  end

  defp exec!(nil) do
    :noop
  end

  defp exec!(%{command: :new, beatmap: b, replay: r}) do
    beatmap = OsuEx.API.get_beatmap!(b)
    resp = HTTPoison.get!(r)
    replay = OsuEx.Replay.parse!(resp.body)
    mode = replay.mode
    player = OsuEx.API.get_user!(replay.player)

    job =
      Job.put!(
        player: player,
        beatmap: beatmap,
        mode: mode,
        replay: Base.encode64(resp.body),
        status: Job.status(:pending),
        skin: Job.skin(player)
      )

    Utils.send_message("Scheduled job `#{job.id}`.")
  end
end
