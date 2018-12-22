defmodule ReplayFarm.MixProject do
  use Mix.Project

  def project do
    [
      app: :replay_farm,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      applications: [:plug_cowboy],
      extra_applications: [:logger],
      mod: {ReplayFarm.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      {:cowboy, "~> 2.6"},
      {:export, "~> 0.1"},
      {:httpoison, "~> 1.5"},
      {:jason, "~> 1.1"},
      {:osu_ex, git: "https://github.com/christopher-dG/osu-ex.git"},
      {:plug_cowboy, "~> 2.0"},
      {:sqlitex, "~> 1.4"}
    ]
  end
end
