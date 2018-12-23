defmodule ReplayFarm.Key do
  @moduledoc "Keys are API keys used by workers."

  alias ReplayFarm.DB

  @table "keys"

  @doc "Gets all API keys"
  @spec get :: {:ok, [binary]} | {:error, term}
  def get do
    case DB.query("SELECT key FROM #{@table}") do
      {:ok, ks} -> Enum.map(ks, &Keyword.get(&1, :key))
      {:error, err} -> {:error, err}
    end
  end

  @doc "Inserts a new API key."
  @spec put(binary) :: binary
  def put(key) do
    case DB.query("INSERT INTO #{@table} (key) VALUES (?1)", bind: [key]) do
      {:ok, _} -> {:ok, key}
      {:error, err} -> {:error, err}
    end
  end
end
