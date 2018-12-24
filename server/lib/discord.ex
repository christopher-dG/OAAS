defmodule ReplayFarm.Discord do
  @moduledoc "The Discord bot."

  alias Nostrum.Api
  use Nostrum.Consumer
  import ReplayFarm.Utils
  alias ReplayFarm.Job
  alias ReplayFarm.Worker

  @me Application.get_env(:replay_farm, :discord_user)
  @channel Application.get_env(:replay_farm, :discord_channel)

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  # Add a job via a replay attachment.
  def handle_event(
        {:MESSAGE_CREATE,
         {%{
            attachments: [%{url: url}],
            mentions: [%{id: @me}],
            channel_id: @channel
          }}, _state}
      ) do
    case Job.from_osr(url) do
      {:ok, j} -> notify("created job `#{j.id}`")
      {:error, reason} -> notify(:error, "creating job failed", reason)
    end
  end

  # Command entrypoint.
  def handle_event(
        {:MESSAGE_CREATE,
         {%{
            content: content,
            mentions: [%{id: @me}],
            channel_id: @channel
          } = msg}, _state}
      ) do
    content
    |> String.split()
    |> tl()
    |> command(msg)
  end

  # Fallback event handler.
  def handle_event(_e) do
    :noop
  end

  def send_message(content) do
    Api.create_message(@channel, content)
  end

  # List workers.
  defp command(["list", "workers"], _msg) do
    case Worker.get() do
      {:ok, ws} ->
        ws
        |> Enum.map(&Map.put(&1, :online, Worker.online?(&1)))
        |> table([:online, :current_job_id], [:online, :job])
        |> send_message()

      {:error, reason} ->
        notify(:error, "listing workers failed", reason)
    end
  end

  # List jobs.
  defp command(["list", "jobs"], _msg) do
    case Job.get() do
      {:ok, js} ->
        js
        |> Enum.reject(&Job.finished/1)
        |> Enum.map(fn j -> Map.update!(j, :status, &Job.status/1) end)
        |> table([:worker_id, :status, :comment], [:worker, :status, :comment])
        |> send_message()

      {:error, reason} ->
        notify(:error, "listing jobs failed", reason)
    end
  end

  # Describe a worker.
  defp command(["describe", "worker", id], _msg) do
    case Worker.get(id) do
      {:ok, w} ->
        last_job =
          if is_nil(w.last_job) do
            "never"
          else
            DateTime.from_unix!(w.last_job, :millisecond)
          end

        """
        ```
        id: #{w.id}
        online: #{Worker.online?(w)}
        job: #{w.current_job_id || "none"}
        last poll: #{DateTime.from_unix!(w.last_poll, :millisecond)}
        last job: #{last_job}
        created: #{DateTime.from_unix!(w.created_at, :millisecond)}
        updated: #{DateTime.from_unix!(w.updated_at, :millisecond)}
        ```
        """
        |> send_message()

      {:error, reason} ->
        notify(:error, "looking up worker failed", reason)
    end
  end

  # Describe a job.
  defp command(["describe", "job", id], _msg) do
    with {id, ""} <- Integer.parse(id),
         {:ok, %Job{} = j} <- Job.get(id) do
      player = "#{j.player.username} (https://osu.ppy.sh/u/#{j.player.user_id})"

      beatmap =
        "#{j.beatmap.artist} - #{j.beatmap.title} [#{j.beatmap.version}] (https://osu.ppy.sh/b/#{
          j.beatmap.beatmap_id
        })"

      """
      ```
      id: #{j.id}
      worker: #{j.worker_id || "none"}
      status: #{Job.status(j.status)}
      comment: #{j.comment || "none"}
      player: #{player}
      beatmap: #{beatmap}
      video: #{j.youtube.title}
      skin: #{(j.skin || %{})[:name] || "none"}
      created: #{DateTime.from_unix!(j.created_at, :millisecond)}
      updated: #{DateTime.from_unix!(j.updated_at, :millisecond)}
      ```
      """
      |> send_message()
    else
      :error -> notify(:error, "invalid job id")
      {:ok, nil} -> notify(:error, "no such job")
      {:error, reason} -> notify(:error, "looking up job failed", reason)
    end
  end

  # Delete a job.
  defp command(["delete", "job", id], _msg) do
    with {id, ""} <- Integer.parse(id),
         {:ok, j} <- Job.get(id),
         {:ok, j} <- Job.delete(j) do
      notify("deleted job `#{j.id}`")
    else
      :error -> notify(:error, "invalid job id")
      {:error, reason} -> notify(:error, "deleting job failed", reason)
    end
  end

  # Fallback command.
  defp command(cmd, _msg) do
    """
    ```
    unrecognized command: #{Enum.join(cmd, " ")}
    usage: <mention> <cmd>
    commands:
    * list (jobs | workers)
    * describe (job | worker) <id>
    * delete job <id>
    or, attach a .osr file to create a new job
    ```
    """
    |> send_message()
  end

  # Generate an ascii table from a list of models.
  @spec table([struct], [atom], [atom]) :: binary
  defp table([], _rows, _headers) do
    "no entries"
  end

  defp table(structs, rows, headers) do
    t =
      structs
      |> Enum.map(fn x ->
        [x.id] ++
          Enum.map(rows, &Map.get(x, &1)) ++
          [
            DateTime.from_unix!(x.created_at, :millisecond),
            DateTime.from_unix!(x.updated_at, :millisecond)
          ]
      end)
      |> TableRex.quick_render!([:id] ++ headers ++ [:created, :updated])

    "```\n#{t}\n```"
  end
end
