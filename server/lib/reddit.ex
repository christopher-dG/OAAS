defmodule ReplayFarm.Reddit do
  @doc "Manages the Python port which interacts with Reddit."

  use GenServer
  use Export.Python

  import ReplayFarm.Utils

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
      {:error, err} -> notify(:warn, "decoding Reddit post failed", err)
    end

    send(self(), :post)
    {:noreply, state}
  end

  # Handle a single Reddit post.
  defp process_post(p) do
    notify(:debug, "processing Reddit post #{p.id}")
  end
end
