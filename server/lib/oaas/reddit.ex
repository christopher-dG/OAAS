defmodule OAAS.Reddit do
  @doc "Manages the Python port which interacts with Reddit."

  use GenServer
  use Export.Python
  import OAAS.Utils
  alias OAAS.Discord

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
        Python.call(state, @module, "save_post", [id])

        """
        reddit post: https://redd.it/#{id}
        title: `#{title}`
        author: `/u/#{author}`
        react :+1: if we should record
        """
        |> Discord.send_message()

      {:error, reason} ->
        notify(:warn, "decoding reddit post failed", reason)
    end

    send(__MODULE__, :post)
    {:noreply, state}
  end
end
