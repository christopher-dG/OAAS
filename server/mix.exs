defmodule OAAS.MixProject do
  use Mix.Project

  def project do
    [
      app: :oaas,
      version: "0.1.0",
      elixir: "~> 1.8",
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
      {:httpoison, "~> 1.5"},
      {:jason, "~> 1.1"},
      {:nostrum, "~> 0.3"},
      {:osu_ex, "~> 0.2"},
      {:plug_cowboy, "~> 2.0"},
      {:reddex, "~> 0.1"},
      {:sqlitex, "~> 1.4"},
      {:table_rex, "~> 2.0.0"}
    ]
  end
end
