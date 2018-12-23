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
      {:error, err} -> notify(:error, "creating job failed", err)
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
        |> table([:online, :current_job_id], ["online", "job"])
        |> send_message()

      {:error, err} ->
        notify(:error, "listing workers failed", err)
    end
  end

  # List jobs.
  defp command(["list", "jobs"], _msg) do
    case Job.get() do
      {:ok, js} ->
        js
        |> Enum.filter(fn j -> not Job.finished(j) end)
        |> Enum.map(fn j -> Map.update!(j, :status, &Job.status/1) end)
        |> table([:worker_id, :status], ["worker", "status"])
        |> send_message()

      {:error, err} ->
        notify(:error, "listing jobs failed", err)
    end
  end

  # Delete a job.
  defp command(["delete", id], _msg) do
    with {id, ""} <- Integer.parse(id),
         {:ok, j} <- Job.get(id),
         {:ok, j} <- Job.delete(j) do
      notify("deleted job `#{j.id}`")
    else
      :error -> notify(:error, "invalid job ID")
      {:error, err} -> notify(:error, "deleting job failed", err)
    end
  end

  # Fallback command.
  defp command(cmd, _msg) do
    send_message("""
    ```
    unrecognized command: #{Enum.join(cmd, " ")}
    usage: <mention> <cmd>
    commands:
    * list workers
    * list jobs
    * delete <job id>
    or, attach a .osr file to create a new job
    ```
    """)
  end

  @spec table([struct], [atom], [binary]) :: binary
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
      |> TableRex.quick_render!(["id"] ++ headers ++ ["created", "updated"])

    "```\n#{t}\n```"
  end
end
