import Config

config :logger,
  compile_time_purge_matching: [
    [application: :nostrum, level_lower_than: :warn],
    [module: Reddex.Auth, level_lower_than: :warn]
  ]

unless match?(["release", _], System.argv()) do
  fetch = fn k ->
    case System.get_env(k) do
      nil ->
        IO.puts("Missing environment variable '#{k}'")
        ""

      v ->
        v
    end
  end

  fetch_int = fn k ->
    with v when v != "" <- fetch.(k),
         {n, ""} <- Integer.parse(v) do
      n
    else
      e ->
        if e === :error, do: IO.puts("Invalid integer environment variable '#{k}'")
        0
    end
  end

  config :nostrum, token: fetch.("DISCORD_API_TOKEN")

  config :osu_ex, api_key: fetch.("OSU_API_KEY")

  config :reddex,
    client_id: fetch.("REDDIT_CLIENT_ID"),
    client_secret: fetch.("REDDIT_CLIENT_SECRET"),
    password: fetch.("REDDIT_PASSWORD"),
    user_agent: fetch.("REDDIT_USER_AGENT"),
    username: fetch.("REDDIT_USERNAME")

  config :oaas,
    discord_admin: fetch_int.("DISCORD_ADMIN_ID"),
    discord_channel: fetch_int.("DISCORD_CHANNEL_ID"),
    discord_user: fetch_int.("DISCORD_USER_ID"),
    osusearch_key: fetch.("OSUSEARCH_API_KEY"),
    port: fetch_int.("PORT"),
    reddit_subreddit: fetch.("REDDIT_SUBREDDIT")
end
