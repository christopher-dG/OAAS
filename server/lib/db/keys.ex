defmodule ReplayFarm.DB.Keys do
  @moduledoc "Provides access to API keys in the database."

  @table "keys"

  @doc "Retrieves all worker API keys from the database."
  @spec get_worker_keys :: {:ok, [binary]} | {:error, term}
  def get_worker_keys() do
    case ReplayFarm.DB.query("select key from #{@table} where not admin") do
      {:ok, keys} -> {:ok, Enum.map(keys, &Keyword.get(&1, :key))}
      {:error, err} -> {:error, err}
    end
  end

  @doc "Retrieves all admin API keys from the database."
  @spec get_admin_keys :: {:ok, [binary]} | {:error, term}
  def get_admin_keys() do
    case ReplayFarm.DB.query("select key from #{@table} where admin") do
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
