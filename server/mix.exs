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

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {OAAS.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      {:cowboy, "~> 2.6"},
      {:export, "~> 0.1"},
      {:httpoison, "~> 1.5", override: true},
      {:jason, "~> 1.1"},
      {:nostrum, git: "https://github.com/Kraigie/nostrum.git"},
      {:osu_ex, git: "https://github.com/christopher-dG/osu-ex.git"},
      {:plug_cowboy, "~> 2.0"},
      {:sqlitex, "~> 1.4"},
      {:table_rex, "~> 2.0.0"}
    ]
  end
end
