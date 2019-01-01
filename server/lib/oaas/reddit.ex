defmodule OAAS.Reddit do
  @doc "Manages the Python port which interacts with Reddit."

  alias ElixirPlusReddit.API, as: RedditAPI
  alias OAAS.Discord
  import OAAS.Utils
  use GenServer

  @subreddit Application.get_env(:oaas, :reddit_subreddit)
  @interval_ms 60_000

  def start_link(_args) do
    GenServer.start_link(__MODULE__, MapSet.new(), name: __MODULE__)
  end

  @impl true
  def init(state) do
    RedditAPI.Identity.self_data(__MODULE__, :me)
    {:ok, state}
  end

  @impl true
  def handle_info({:me, %{name: name}}, state) do
    RedditAPI.User.saved(__MODULE__, :saved, name)
    {:noreply, state}
  end

  @impl true
  def handle_info({:saved, %{children: posts}}, state) do
    RedditAPI.Subreddit.stream_submissions(__MODULE__, :posts, @subreddit, @interval_ms)

    {:noreply,
     posts
     |> Enum.map(&Map.get(&1, :id))
     |> MapSet.new()
     |> MapSet.union(state)}
  end

  @impl true
  def handle_info({:posts, %{children: posts}}, state) do
    {:noreply,
     Enum.reduce(posts, state, fn %{id: id, title: title, permalink: url, name: name} = p, acc ->
       if id not in acc and Map.has_key?(p, :author) and Regex.match?(~r/.+\|.+-.+\[.+\]/, title) do
         notify(:debug, "Processing reddit post https://redd.it/#{id}.")

         """
         New Reddit post `#{id}`.
         URL: https://reddit.com#{url}
         Title: `#{title}`
         Author: `/u/#{p.author}`
         React :+1: if we should record.
         """
         |> Discord.send_message()

         RedditAPI.Post.save(self(), :save, name)
         MapSet.put(acc, id)
       else
         acc
       end
     end)}
  end

  @impl true
  def handle_info({:save, _errors}, state) do
    {:noreply, state}
  end
end
