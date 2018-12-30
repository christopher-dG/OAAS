defmodule OAAS.Reddit do
  @doc "Manages the Python port which interacts with Reddit."

  alias OAAS.Discord
  import OAAS.Utils
  use Export.Python
  use GenServer

  @pypath "priv"
  @module "reddit"

  def start_link(_args) do
    {:ok, pid} = Python.start_link(python_path: Path.absname(@pypath))
    GenServer.start_link(__MODULE__, pid, name: __MODULE__)
  end

  @impl true
  def init(state) do
    send(__MODULE__, :post)
    {:ok, state}
  end

  @impl true
  def handle_info(:post, state) do
    json = Python.call(state, @module, "next_post", [])

    case Jason.decode(json) do
      {:ok, p} ->
        %{id: id, title: title, author: author} = atom_map(p)
        notify(:debug, "Processing reddit post https://redd.it/#{id}.")
        Python.call(state, @module, "save_post", [id])

        """
        New Reddit post: <https://redd.it/#{id}>
        Title: `#{title}`
        Author: `/u/#{author}`
        React :+1: if we should record.
        """
        |> Discord.send_message()

      {:error, reason} ->
        notify(:warn, "Decoding reddit post failed.", reason)
    end

    send(__MODULE__, :post)
    {:noreply, state}
  end
end
