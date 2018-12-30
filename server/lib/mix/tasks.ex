defmodule Mix.Tasks.Key do
  defmodule List do
    use Mix.Task

    @shortdoc "Lists API keys."
    def run(_arg) do
      Logger.configure(level: :warn)

      with :ok <- OAAS.Utils.start_db(),
           {:ok, keys} <- OAAS.Key.get() do
        keys
        |> Enum.map(&Map.get(&1, :id))
        |> Enum.join("\n")
        |> IO.puts()
      else
        {:error, reason} ->
          IO.puts("listing keys failed: #{inspect(reason)}")
          exit({:shutdown, 1})
      end
    end
  end

  defmodule Add do
    use Mix.Task
    require OAAS.DB

    @shortdoc "Adds API keys (space-delimited) to the database."
    def run(keys) do
      Logger.configure(level: :warn)

      with :ok <- OAAS.Utils.start_db(),
           {:ok, _} <-
             (OAAS.DB.transaction do
                Enum.each(keys, fn k ->
                  case OAAS.Key.put(id: k) do
                    {:ok, _} -> :noop
                    {:error, {:constraint, 'UNIQUE constraint failed: keys.id'}} -> :noop
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

  defmodule Delete do
    use Mix.Task
    require OAAS.DB

    @shortdoc "Deletes API keys (space-delimited) from the database."
    def run(keys) do
      Logger.configure(level: :warn)

      with :ok <- OAAS.Utils.start_db(),
           {:ok, _} <-
             (OAAS.DB.transaction do
                Enum.each(keys, fn k ->
                  case OAAS.Key.delete(k) do
                    :ok -> :noop
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
end
