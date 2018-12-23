defmodule ReplayFarm.Discord do
  alias ReplayFarm.Job
  alias Nostrum.Api
  use Nostrum.Consumer
  require Logger

  @me Application.get_env(:replay_farm, :discord_user)
  @channel Application.get_env(:replay_farm, :discord_channel)

  def start_link, do: Consumer.start_link(__MODULE__)

  def handle_event(
        {:MESSAGE_CREATE,
         {%{
            attachments: [%{url: url}],
            mentions: [%{id: @me}],
            channel_id: @channel
          }}, _state}
      ) do
    j = Job.from_osr!(url)
    notify("Created job `#{j.id}`")
  end

  def handle_event(_event), do: :noop

  def notify(content) when is_binary(content) do
    Logger.info(content)
    Api.create_message(@channel, content)
  end
end
