defmodule OAAS.Utils do
  @moduledoc "Common utility functions."

  alias OAAS.DB
  alias OAAS.Discord
  require Logger

  @doc "Starts the database."
  @spec start_db :: :ok | {:error, term}
  def start_db do
    with {:ok, _} <- Sqlitex.Server.start_link("priv/db_#{Mix.env()}.sqlite3", name: OAAS.DB),
         {:ok, _} <- DB.start_link([]) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Converts a map's string keys to atoms."
  @spec atom_map(map) :: map
  def atom_map(x) when is_map(x) do
    x
    |> Enum.map(&atom_map/1)
    |> Map.new()
  end

  @spec atom_map(list) :: list
  def atom_map(x) when is_list(x) do
    Enum.map(x, &atom_map/1)
  end

  @spec atom_map({String.t(), term}) :: {atom, term}
  def atom_map({k, v}) when is_binary(k) do
    {String.to_atom(k), atom_map(v)}
  end

  @spec atom_map({term, term}) :: {term, term}
  def atom_map({k, v}) do
    {k, atom_map(v)}
  end

  @spec atom_map(term) :: term
  def atom_map(x) do
    x
  end

  @spec notify(String.t()) :: true
  def notify(msg) do
    notify(:info, msg)
  end

  @spec notify(:debug, String.t()) :: true
  def notify(:debug, msg) do
    Logger.debug(msg)
    true
  end

  @spec notify(:info, String.t()) :: true
  def notify(:info, msg) do
    Logger.info(msg)
    Task.start(fn -> Mix.env() === :test || Discord.send_message("info: #{msg}") end)
    true
  end

  @spec notify(:warn, String.t()) :: true
  def notify(:warn, msg) do
    Logger.warn(msg)
    Task.start(fn -> Mix.env() === :test || Discord.send_message("warn: #{msg}") end)
    true
  end

  @spec notify(:error, String.t()) :: true
  def notify(:error, msg) do
    Logger.error(msg)
    Task.start(fn -> Mix.env() === :test || Discord.send_message("error: #{msg}") end)
    true
  end

  @spec notify(:debug, String.t(), term) :: true
  def notify(:debug, msg, err) do
    notify(:debug, "#{msg}: #{inspect(err)}")
  end

  @spec notify(:warn, String.t(), term) :: true
  def notify(:warn, msg, err) do
    notify(:warn, "#{msg}: `#{inspect(err)}`")
  end

  @spec notify(:error, String.t(), term) :: true
  def notify(:error, msg, err) do
    notify(:error, "#{msg}: `#{inspect(err)}`")
  end

  @doc "Humanizes a timestamp."
  @spec relative_time(nil) :: String.t()
  def relative_time(nil) do
    "never"
  end

  @spec relative_time(integer) :: String.t()
  def relative_time(ms) do
    case round((System.system_time(:millisecond) - ms) / 1000) do
      0 -> "now"
      1 -> "a second ago"
      s when s < 60 -> "#{s} seconds ago"
      60 -> "a minute ago"
      s when s < 3600 -> "#{round(s / 60)} minutes ago"
      s when s < 5400 -> "an hour ago"
      s when s < 86400 -> "#{round(s / 3600)} hours ago"
      s when s < 129_600 -> "a day ago"
      s -> "#{round(s / 86400)} days ago"
    end
  end
end
