defmodule ReplayFarm.Key do
  @moduledoc "Keys are API keys used by workers and admins."

  alias ReplayFarm.DB

  @table "keys"

  @doc "Gets all API keys"
  @spec get :: {:ok, [binary]} | {:error, term}
  def get do
    sql = "SELECT key FROM #{@table}"

    case DB.query(sql) do
      {:ok, keys} -> {:ok, Enum.map(keys, &Map.get(&1, :key))}
      {:error, err} -> {:error, err}
    end
  end

  @doc "Inserts a new API key."
  @spec put(binary) :: :ok | {:error, term}
  def put(key) when is_binary(key) do
    sql = "INSERT INTO #{@table} (key) VALUES (?1)"

    case DB.query(sql, bind: [key]) do
      {:ok, _} -> :ok
      {:error, err} -> {:error, err}
    end
  end
end
