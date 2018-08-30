defmodule ReplayFarm.Keys do
  @moduledoc "Keys are API keys used by workers and admins."

  alias ReplayFarm.DB

  @table "keys"

  @doc "Gets all worker or admin API keys (one category, not both)."
  @spec get_keys(boolean) :: {:ok, [binary]} | {:error, term}
  def get_keys(admin?) when is_boolean(admin?) do
    maybe = if(admin?, do: "", else: "not")
    sql = "SELECT key FROM ?1 WHERE #{maybe} admin"

    case DB.query(sql, bind: [@table]) do
      {:ok, keys} -> {:ok, Enum.map(keys, &Map.get(&1, :key))}
      {:error, err} -> {:error, err}
    end
  end

  @doc "Inserts a new API key."
  @spec put_key(binary, boolean) :: :ok | {:error, term}
  def put_key(key, admin?) when is_binary(key) and is_boolean(admin?) do
    sql = "INSERT INTO #{@table} (key, admin) VALUES (?1, ?2)"

    case DB.query(sql, bind: [key, admin?]) do
      {:ok, _} -> :ok
      {:error, err} -> {:error, err}
    end
  end
end
