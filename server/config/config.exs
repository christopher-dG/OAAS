use Mix.Config

config :logger, compile_time_purge_matching: [[application: :nostrum, level_lower_than: :warn]]

config :nostrum, token: System.get_env("DISCORD_TOKEN")

config :osu_ex, api_key: System.get_env("OSU_API_KEY")

config :oaas,
  port: (System.get_env("PORT") || "4000") |> Integer.parse() |> elem(0),
  discord_user: System.get_env("DISCORD_USER") |> Integer.parse() |> elem(0),
  discord_channel: System.get_env("DISCORD_CHANNEL") |> Integer.parse() |> elem(0)
