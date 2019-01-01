use Mix.Config

config :logger, compile_time_purge_matching: [[application: :nostrum, level_lower_than: :warn]]

# Your Discord application's bot token: https://discordapp.com/developers/applications/me.
config :nostrum, token: System.get_env("DISCORD_TOKEN")

# Your osu! API key: https://osu.ppy.sh/p/api.
config :osu_ex, api_key: System.get_env("OSU_API_KEY")

# Your Reddit credentials: https://www.reddit.com/prefs/apps.
config :elixirplusreddit,
  user_agent: System.get_env("REDDIT_USER_AGENT"),
  creds: [
    username: System.get_env("REDDIT_USERNAME"),
    password: System.get_env("REDDIT_PASSWORD"),
    client_id: System.get_env("REDDIT_CLIENT_ID"),
    client_secret: System.get_env("REDDIT_CLIENT_SECRET")
  ]

config :oaas,
  # Path to this script: https://github.com/omkelderman/osu-replay-downloader/blob/master/fetch.js.
  osr_downloader: System.get_env("OSR_DOWNLOADER"),
  # Web server port.
  port: (System.get_env("PORT") || "4000") |> Integer.parse() |> elem(0),
  # Discord bot user ID.
  discord_user: (System.get_env("DISCORD_USER") || "0") |> Integer.parse() |> elem(0),
  # Discord channel ID where the bot will post.
  discord_channel: (System.get_env("DISCORD_CHANNEL") || "0") |> Integer.parse() |> elem(0),
  # osusearch.com API key.
  osusearch_key: System.get_env("OSUSEARCH_API_KEY"),
  # Reddit subreddit to pol.
  reddit_subreddit: System.get_env("REDDIT_SUBREDDIT")
