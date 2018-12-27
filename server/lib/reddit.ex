defmodule OAAS.Reddit do
  @doc "Manages the Python port which interacts with Reddit."

  use GenServer
  use Export.Python
  import OAAS.Utils
  alias OAAS.Discord

  @pypath "priv"
  @module "reddit"

  def start_link(_args) do
    {:ok, pid} = Python.start_link(python_path: @pypath)
    GenServer.start_link(__MODULE__, pid)
  end

  @impl true
  def init(state) do
    send(self(), :post)
    {:ok, state}
  end

  @impl true
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

  @impl true
  def handle_cast({:save, id}, state) do
    Python.call(state, @module, "save_post", [id])
    {:noreply, state}
  end

  # Saves a Reddit post by ID.
  defp save_post(id) do
    GenServer.cast(self(), {:save, id})
  end

  # Handle a single Reddit post.
  defp process_post(%{id: id, title: title, author: author}) do
    """
    reddit post: https://redd.it/#{id}
    title: `#{title}`
    author: `/u/#{author}`
    react :+1: if we should record
    """
    |> Discord.send_message()
  end
end
