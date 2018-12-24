defmodule Mix.Tasks.Key.List do
  use Mix.Task

  @shortdoc "Lists API keys."
  def run(_arg) do
    with {:ok, _} <- Sqlitex.Server.start_link("priv/db_#{Mix.env()}.sqlite3", name: OAAS.DB),
         {:ok, _} <- OAAS.DB.start_link([]),
         {:ok, keys} <- OAAS.Key.get() do
      keys
      |> Enum.join("\n")
      |> IO.puts()
    else
      {:error, reason} ->
        IO.puts("listing keys failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end
end

defmodule Mix.Tasks.Key.Add do
  use Mix.Task

  @shortdoc "Adds an API key to the database."
  def run(key) do
    with {:ok, _} <- Sqlitex.Server.start_link("priv/db_#{Mix.env()}.sqlite3", name: OAAS.DB),
         {:ok, _} <- OAAS.DB.start_link([]),
         {:ok, key} <- OAAS.Key.put(key) do
      IO.puts("added key #{key}")
    else
      {:error, reason} ->
        IO.puts("adding key failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end
end

defmodule Mix.Tasks.Key.Delete do
  use Mix.Task

  @shortdoc "Deletes an API key to the database."
  def run(key) do
    with {:ok, _} <- Sqlitex.Server.start_link("priv/db_#{Mix.env()}.sqlite3", name: OAAS.DB),
         {:ok, _} <- OAAS.DB.start_link([]),
         {:ok, key} <- OAAS.Key.delete(key) do
      IO.puts("deleted key #{key}")
    else
      {:error, reason} ->
        IO.puts("deleting key failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end
end
