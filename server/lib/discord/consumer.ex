defmodule ReplayFarm.Discord.Consumer do
  @doc "The Discord bot."

  use Nostrum.Consumer
  alias Nostrum.Api
  require Logger

  alias ReplayFarm.Discord.Utils
  alias ReplayFarm.Discord.Command

  @thumbs_up "👍"
  @reaction_threshold 3

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  # Handles bot mentions..
  def handle_event({:MESSAGE_CREATE, {data}, _state}) do
    bot = Utils.me()

    if Enum.any?(data.mentions, fn u -> u.id === bot.id end) do
      Logger.info("received mention: #{data.content}")

      data.content
      |> String.replace_prefix(Nostrum.Struct.User.mention(bot), "")
      |> String.trim_leading()
      |> String.downcase()
      |> String.split(" ")
      |> Command.parse()
      |> Command.validate()
      |> Command.exec()
    end
  end

  # Handles thumbs-up reactions.
  def handle_event({:MESSAGE_REACTION_ADD, {%{emoji: %{name: @thumbs_up}} = data}, _state}) do
    bot = Utils.me()

    unless data.user_id === bot.id do
      msg = Api.get_channel_message!(data.channel_id, data.message_id)

      if msg.author.id === bot.id do
        Logger.info("received +1 reaction on message #{msg.id}")
        reaction = Enum.find(msg.reactions, fn r -> r.emoji.name === @thumbs_up end)

        if (reaction || %{count: 0}).count === @reaction_threshold do
          :todo
        end
      end
    end
  end

  def handle_event(_evt) do
    :noop
  end
end
