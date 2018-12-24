defmodule OAAS.Key do
  @moduledoc "Keys are API keys used by workers."

  alias OAAS.DB

  @table "keys"

  @doc "Gets all API keys"
  @spec get :: {:ok, [binary]} | {:error, term}
  def get do
    case DB.query("SELECT key FROM #{@table}") do
      {:ok, ks} -> {:ok, Enum.map(ks, &Keyword.get(&1, :key))}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Inserts a new API key."
  @spec put(binary) :: {:ok, binary} | {:error, term}
  def put(key) do
    case DB.query("INSERT INTO #{@table} (key) VALUES (?1)", bind: [key]) do
      {:ok, _} -> {:ok, key}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Deletes an API key."
  @spec delete(binary) :: {:ok, binary} | {:error, term}
  def delete(key) do
    case DB.query("DELETE FROM #{@table} WHERE key = ?1", bind: [key]) do
      {:ok, _} -> {:ok, key}
      {:error, reason} -> {:error, reason}
    end
  end
end
