defmodule ReplayFarm.Discord do
  @moduledoc "The Discord bot."

  alias ReplayFarm.Job
  alias Nostrum.Api
  use Nostrum.Consumer
  import ReplayFarm.Utils

  @me Application.get_env(:replay_farm, :discord_user)
  @channel Application.get_env(:replay_farm, :discord_channel)

  def start_link do
    Consumer.start_link(__MODULE__)
  end

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

  def handle_event(_event) do
    :noop
  end

  def send_message(content) do
    Api.create_message(@channel, content)
  end
end
