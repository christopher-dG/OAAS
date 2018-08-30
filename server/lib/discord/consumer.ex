defmodule ReplayFarm.Discord.Consumer do
  @doc "The Discord bot."

  use Nostrum.Consumer
  alias Nostrum.Api
  require Logger

  @thumbs_up "👍"
  @reaction_threshold 3

  def start_link, do: Consumer.start_link(__MODULE__)

  # Handles bot mentions..
  def handle_event({:MESSAGE_CREATE, {data}, _state}) do
    me = me_id()

    if Enum.any?(data.mentions, fn u -> u.id === me end) do
      Logger.info("received mention: #{data.content}")

      case data.content do
        _ -> :noop
      end
    end
  end

  # Handles thumbs-up reactions.
  def handle_event({:MESSAGE_REACTION_ADD, {%{emoji: %{name: @thumbs_up}} = data}, _state}) do
    unless data.user_id === me_id() do
      msg = Api.get_channel_message!(data.channel_id, data.message_id)

      if msg.author.id === me_id() do
        Logger.info("received +1 reaction on message #{msg.id}")
        reaction = Enum.find(msg.reactions, fn r -> r.emoji.name === @thumbs_up end)

        if (reaction || %{count: 0}).count === @reaction_threshold do
          :todo
        end
      end
    end
  end

  def handle_event(_evt), do: :noop

  # Get the bot's user ID.
  defp me_id do
    case Nostrum.Cache.Me.get() do
      %{id: id} -> id
      _ -> nil
    end
  end
end
