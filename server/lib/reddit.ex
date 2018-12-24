defmodule OAAS.Reddit do
  @doc "Manages the Python port which interacts with Reddit."

  use GenServer
  use Export.Python
  import OAAS.Utils

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
      {:ok, p} ->
        p
        |> atom_map()
        |> process_post()

      {:error, reason} ->
        notify(:warn, "decoding reddit post failed", reason)
    end

    send(self(), :post)
    {:noreply, state}
  end

  # Handle a single Reddit post.
  defp process_post(p) do
    notify(:debug, "processing reddit post #{p.id}")
  end
end
