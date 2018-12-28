defmodule OAAS.Discord do
  @moduledoc "The Discord bot."

  alias Nostrum.Api
  use Nostrum.Consumer
  import OAAS.Utils
  alias OAAS.Job
  alias OAAS.Job.Replay
  alias OAAS.Worker

  @me Application.get_env(:oaas, :discord_user)
  @channel Application.get_env(:oaas, :discord_channel)
  @plusone "👍"

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  # Add a job via a replay attachment.
  def handle_event(
        {:MESSAGE_CREATE,
         {%{
            attachments: [%{url: url}],
            channel_id: @channel,
            content: content,
            mentions: [%{id: @me}]
          }}, _state}
      ) do
    skin =
      case Regex.run(~r/skin:(.+)/i, content, capture: :all_but_first) do
        [skin] -> String.trim(skin)
        nil -> nil
      end

    case Replay.from_osr(url, skin) do
      {:ok, j} -> notify("created job `#{j.id}`")
      {:error, reason} -> notify(:error, "creating job failed", reason)
    end
  end

  # Command entrypoint.
  def handle_event(
        {:MESSAGE_CREATE,
         {%{
            content: content,
            channel_id: @channel,
            mentions: [%{id: @me}]
          } = msg}, _state}
      ) do
    content
    |> String.split()
    |> tl()
    |> command(msg)
  end

  # Add a job via a reaction on a Reddit post notification.
  def handle_event(
        {:MESSAGE_REACTION_ADD,
         {%{
            channel_id: @channel,
            emoji: %{name: @plusone},
            message_id: message
          }}, _state}
      ) do
    case Api.get_channel_message(@channel, message) do
      {:ok, %{author: %{id: @me}, content: "reddit post:" <> content}} ->
        with [p_id] <- Regex.run(~r/https:\/\/redd.it\/(.+)/i, content, capture: :all_but_first),
             [title] <- Regex.run(~r/title: `(.+)`/i, content, capture: :all_but_first) do
          case Replay.from_reddit(p_id, title) do
            {:ok, j} ->
              notify(
                """
                created job `#{j.id}`
                ensure that this is accurate, or run `delete job #{j.id}` immediately
                """ <> "\n" <> Replay.describe(j)
              )

            {:error, reason} ->
              notify(:error, "creating job failed", reason)
          end
        else
          nil -> notify(:warn, "parsing message failed")
        end

      {:ok, msg} ->
        notify(:debug, "message #{msg.id} is not a reddit notification")

      {:error, reason} ->
        notify(:warn, "getting message #{message} failed", reason)
    end
  end

  # Fallback event handler.
  def handle_event(_e) do
    :noop
  end

  @doc "Sends a Discord message."
  @spec send_message(binary) :: {:ok, Nostrum.Struct.Message.t()} | {:error, term}
  def send_message(content) do
    case Api.create_message(@channel, content) do
      {:ok, msg} ->
        {:ok, msg}

      {:error, reason} ->
        notify(:debug, "sending message failed", reason)
        {:error, reason}
    end
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
        w
        |> Worker.describe()
        |> send_message()

      {:error, reason} ->
        notify(:error, "looking up worker failed", reason)
    end
  end

  # Describe a job.
  defp command(["describe", "job", id], _msg) do
    with {id, ""} <- Integer.parse(id),
         {:ok, j} <- Job.get(id) do
      j
      |> Replay.describe()
      |> send_message()
    else
      :error -> notify(:error, "invalid job id")
      {:error, reason} -> notify(:error, "looking up job failed", reason)
    end
  end

  # Delete a job.
  defp command(["delete", "job", id], _msg) do
    with {id, ""} <- Integer.parse(id),
         {:ok, j} <- Job.get(id),
         {:ok, j} <- Job.mark_deleted(j) do
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
          [relative_time(x.created_at), relative_time(x.updated_at)]
      end)
      |> TableRex.quick_render!([:id] ++ headers ++ [:created, :updated])

    "```\n#{t}\n```"
  end
end
