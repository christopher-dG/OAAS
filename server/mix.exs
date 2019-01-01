defmodule OAAS.MixProject do
  use Mix.Project

  def project do
    [
      app: :oaas,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:elixirplusreddit, github: "christopher-dG/ElixirPlusReddit"},
      {:httpoison, "~> 1.5", override: true},
      {:jason, "~> 1.1"},
      {:nostrum, github: "Kraigie/nostrum"},
      {:osu_ex, github: "christopher-dG/osu-ex"},
      {:plug_cowboy, "~> 2.0"},
      {:poison, "~> 4.0", override: true},
      {:sqlitex, "~> 1.4"},
      {:table_rex, "~> 2.0.0"}
    ]
  end
end
