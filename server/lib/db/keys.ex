defmodule ReplayFarm.DB.Keys do
  @moduledoc "Provides access to API keys in the database."

  @table "keys"

  @doc "Retrieves all worker or admin API keys from the database (one category, not both)."
  @spec get_keys(boolean) :: {:ok, [binary]} | {:error, term}
  def get_keys(admin?) when is_boolean(admin?) do
    maybe = if(admin?, do: "", else: "not")

    case ReplayFarm.DB.query("select key from #{@table} where #{maybe} admin") do
      {:ok, keys} -> {:ok, Enum.map(keys, &Keyword.get(&1, :key))}
      {:error, err} -> {:error, err}
    end
  end

  @doc "Inserts a new API key into the database."
  @spec put_key(binary, boolean) :: :ok | {:error, term}
  def put_key(key, admin?) when is_binary(key) and is_boolean(admin?) do
    case ReplayFarm.DB.query("insert into #{@table} (key, admin) values (?1, ?2)",
           bind: [key, admin?]
         ) do
      {:ok, _} -> :ok
      {:error, err} -> {:error, err}
    end
  end
end
