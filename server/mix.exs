defmodule OAAS.MixProject do
  use Mix.Project

  @config {:config_providers, [{OAAS.ConfigProvider, "config.toml"}]}

  def project do
    [
      app: :oaas,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() === :prod,
      deps: deps(),
      default_release: :dev,
      releases: [
        dev: [
          @config,
          applications: [runtime_tools: :permanent],
          strip_beams: false,
          include_executables_for: [:unix]
        ],
        prod: [@config]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {OAAS.Application, []}
    ]
  end

  defp deps do
    [
      {:cowboy, "~> 2.6"},
      {:httpoison, "~> 1.5"},
      {:jason, "~> 1.1"},
      {:nostrum, "~> 0.3"},
      {:osu_ex, "~> 0.2"},
      {:plug_cowboy, "~> 2.0"},
      {:reddex, "~> 0.1"},
      {:sqlitex, "~> 1.7"},
      {:table_rex, "~> 2.0"},
      {:toml, "~> 0.5"}
    ]
  end
end
