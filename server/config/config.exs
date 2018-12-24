use Mix.Config

config :logger, compile_time_purge_matching: [[application: :nostrum, level_lower_than: :warn]]

# Your Discord application's bot token.
config :nostrum, token: System.get_env("DISCORD_TOKEN")

# Your osu! API key.
config :osu_ex, api_key: System.get_env("OSU_API_KEY")

# Your HTTP server port, Discord bot user ID, and Discord interaction channel ID.
config :oaas,
  port: (System.get_env("PORT") || "4000") |> Integer.parse() |> elem(0),
  discord_user: (System.get_env("DISCORD_USER") || "0") |> Integer.parse() |> elem(0),
  discord_channel: (System.get_env("DISCORD_CHANNEL") || "0") |> Integer.parse() |> elem(0)
