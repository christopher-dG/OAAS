defmodule OAAS.Reddit do
  @moduledoc "Receives Reddit post notifications and forwards some to Discord."

  alias OAAS.Discord
  alias Reddex.Stream
  alias Reddex.API.Post
  alias Reddex.API.Subreddit
  import OAAS.Utils

  @spec subreddit :: String.t()
  defp subreddit, do: Application.fetch_env!(:oaas, :reddit_subreddit)

  def start_link(_args), do: Task.start_link(&process_posts/0)

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def process_posts do
    Stream.create(&Subreddit.new/2, subreddit())
    |> Enum.each(fn p ->
      cond do
        p.saved ->
          notify(:debug, "Skipping Reddit post https://redd.it/#{p.id} (saved).")

        not Regex.match?(~r/.+\|.+-.+\[.+\]/, p.title) ->
          notify(:debug, "Skipping Reddit post https://redd.it/#{p.id} (title).")

        true ->
          notify(:debug, "Processing Reddit post https://redd.it/#{p.id}.")

          """
          New Reddit post `#{p.id}`.
          URL: https://reddit.com#{p.permalink}
          Title: `#{p.title}`
          Author: `/u/#{p.author}`
          React :+1: if we should record.
          """
          |> Discord.send_message()

          Post.save(p)
      end
    end)
  end
end
