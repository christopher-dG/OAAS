defmodule ReplayFarm.Discord.Utils do
  @moduledoc "Discord utility functions."

  require Logger
  alias Nostrum.Api

  @doc "Returns the bot's Discord channel ID."
  @spec channel :: binary
  def channel do
    Application.get_env(:replay_farm, :discord_channel)
    |> Integer.parse()
    |> elem(0)
  end

  @doc "Sends a message to the discord channel."
  @spec send_message(binary) :: :ok
  def send_message(msg) do
    Logger.info("sending message: #{msg}")

    case Api.create_message(channel(), content: msg) do
      {:ok, _} -> :ok
      {:error, err} -> Logger.error("sending message failed: #{inspect(err)}")
    end
  end

  @doc "Get the bot's user data."
  @spec me :: map | nil
  def me do
    Nostrum.Cache.Me.get() || %{id: nil}
  end
end
