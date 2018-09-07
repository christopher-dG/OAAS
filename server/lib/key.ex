defmodule ReplayFarm.Key do
  @moduledoc "Keys are API keys used by workers."

  alias ReplayFarm.DB

  @table "keys"

  @doc "Gets all API keys"
  @spec get! :: {:ok, [binary]} | {:error, term}
  def get! do
    sql = "SELECT key FROM #{@table}"
    DB.query!(sql) |> Enum.map(&Map.get(&1, :key))
  end

  @doc "Inserts a new API key."
  @spec put!(binary) :: binary
  def put!(key) when is_binary(key) do
    sql = "INSERT INTO #{@table} (key) VALUES (?1)"
    bind = [key]

    DB.query!(sql, bind: bind)
    key
  end
end
