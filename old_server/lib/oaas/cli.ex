defmodule OAAS.CLI do
  @moduledoc "Useful functions for use from the command line."

  alias OAAS.DB
  alias OAAS.Key
  alias OAAS.Utils
  require Logger

  def list_keys do
    task_wrapper(fn ->
      case Key.get() do
        {:ok, keys} ->
          keys
          |> Enum.map(&Map.get(&1, :id))
          |> Enum.join("\n")
          |> IO.puts()

          {:ok, nil}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  def add_keys(keys) when is_list(keys) do
    task_wrapper(fn ->
      DB.transaction(fn ->
        keys
        |> Enum.map(&to_string/1)
        |> Enum.each(fn k ->
          case Key.put(id: k) do
            {:ok, _} -> :noop
            {:error, {:constraint, 'UNIQUE constraint failed: keys.id'}} -> :noop
            {:error, reason} -> throw(reason)
          end
        end)
      end)
    end)
  end

  def add_keys(key), do: add_keys([key])

  def delete_keys(keys) when is_list(keys) do
    task_wrapper(fn ->
      DB.transaction(fn ->
        keys
        |> Enum.map(&to_string/1)
        |> Enum.each(fn k ->
          case Key.delete(k) do
            :ok -> :noop
            {:error, reason} -> throw(reason)
          end
        end)
      end)
    end)
  end

  def delete_keys(key), do: delete_keys([key])

  defp task_wrapper(fun) do
    with :ok <- Logger.configure(level: :info),
         :ok <- Utils.start_db(),
         {:ok, _} <- fun.() do
      :ok
    else
      {:error, reason} ->
        IO.puts(:stderr, "Task failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
