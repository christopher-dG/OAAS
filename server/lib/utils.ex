defmodule ReplayFarm.Utils do
  @moduledoc "Common utility functions."

  alias ReplayFarm.Discord
  require Logger

  @spec notify(binary) :: true
  def notify(msg) do
    notify(:info, msg)
  end

  @spec notify(:debug, binary) :: true
  def notify(:debug, msg) do
    Logger.debug(msg)
    true
  end

  @spec notify(:info, binary) :: true
  def notify(:info, msg) do
    Logger.info(msg)
    Task.start(fn -> Mix.env() === :test || Discord.send_message("info: #{msg}") end)
    true
  end

  @spec notify(:warn, binary) :: true
  def notify(:warn, msg) do
    Logger.warn(msg)
    Task.start(fn -> Mix.env() === :test || Discord.send_message("warn: #{msg}") end)
    true
  end

  @spec notify(:error, binary) :: true
  def notify(:error, msg) do
    Logger.error(msg)
    Task.start(fn -> Mix.env() === :test || Discord.send_message("error: #{msg}") end)
    true
  end

  @spec notify(:warn, binary, term) :: true
  def notify(:warn, msg, err) do
    notify(:warn, "#{msg}: `#{inspect(err)}`")
  end

  @spec notify(:error, binary, term) :: true
  def notify(:error, msg, err) do
    notify(:error, "#{msg}: `#{inspect(err)}`")
  end
end
