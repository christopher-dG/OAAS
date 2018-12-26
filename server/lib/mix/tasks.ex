defmodule Mix.Tasks.Key.List do
  use Mix.Task

  @shortdoc "Lists API keys."
  def run(_arg) do
    with :ok <- OAAS.Utils.start_db(),
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
  require OAAS.DB

  @shortdoc "Adds API keys (space-delimited) to the database."
  def run(keys) do
    with :ok <- OAAS.Utils.start_db(),
         {:ok, _} <-
           (OAAS.DB.transaction do
              Enum.each(keys, fn k ->
                case OAAS.Key.put(k) do
                  {:ok, _} -> :noop
                  {:error, reason} -> throw(reason)
                end
              end)
            end) do
      IO.puts("added #{length(keys)} key(s)")
    else
      {:error, reason} ->
        IO.puts("adding keys failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end
end

defmodule Mix.Tasks.Key.Delete do
  use Mix.Task
  require OAAS.DB

  @shortdoc "Deletes API keys (space-delimited) from the database."
  def run(keys) do
    with :ok <- OAAS.Utils.start_db(),
         {:ok, _} <-
           (OAAS.DB.transaction do
              Enum.each(keys, fn k ->
                case OAAS.Key.delete(k) do
                  {:ok, _} -> :noop
                  {:error, reason} -> throw(reason)
                end
              end)
            end) do
      IO.puts("deleted #{length(keys)} key(s)")
    else
      {:error, reason} ->
        IO.puts("deleting keys failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end
end
