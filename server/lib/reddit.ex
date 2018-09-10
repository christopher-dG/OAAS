defmodule ReplayFarm.Reddit do
  @doc "Manages the Python port which interacts with Reddit."

  use GenServer
  require Logger
  use Export.Python

  @module "priv.reddit"

  def start_link(_args) do
    {:ok, pid} = Python.start_link()
    GenServer.start_link(__MODULE__, pid)
  end

  def init(state) do
    send(self(), :post)
    {:ok, state}
  end

  def handle_info(:post, state) do
    json = Python.call(state, @module, "next_post", [])

    case Jason.decode(json) do
      {:ok, p} -> process_post(p)
      {:error, err} -> Logger.error("Decoding post failed: #{err}")
    end

    send(self(), :post)
    {:noreply, state}
  end

  # Handle a single Reddit post.
  defp process_post(p) do
    Logger.info("Processing post #{inspect(p)}")
  end
end
