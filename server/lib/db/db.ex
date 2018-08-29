defmodule ReplayFarm.DB do
  @moduledoc "Defines and executes the schema at startup."

  require Logger

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def start_link(_opts) do
    create_table!("keys", key: {:text, [:primary_key]}, admin: {:boolean, [:not_null]})
    {:ok, self()}
  end

  @doc "Execute a database query."
  def query(query, opts \\ []) when is_binary(query) and is_list(opts) do
    {decode, opts} = Keyword.pop(opts, :decode, [])

    case Sqlitex.Server.query(ReplayFarm.DB, query, opts) do
      {:ok, results} ->
        if String.starts_with?(query, "select") do
          {:ok,
           Enum.map(results, fn row ->
             Enum.map(row, fn {k, v} ->
               if k in decode do
                 case Jason.decode(v) do
                   {:ok, decoded} ->
                     {k, decoded}

                   {:error, err} ->
                     Logger.warn("couldn't decode column #{k}: #{inspect(err)}")
                     {k, v}
                 end
               else
                 {k, v}
               end
             end)
           end)}
        else
          {:ok, results}
        end

      {:error, err} ->
        {:error, err}
    end
  end

  # Creates a database table.
  defp create_table!(name, cols) do
    case Sqlitex.Server.create_table(ReplayFarm.DB, name, cols) do
      {:error, {:sqlite_error, err}} ->
        unless String.ends_with?(List.to_string(err), "already exists") do
          raise err
        end

      _ ->
        :ok
    end
  end
end
