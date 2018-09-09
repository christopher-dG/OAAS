defmodule ReplayFarm.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    File.mkdir_p("priv")
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: ReplayFarm.Worker.start_link(arg)
      %{
        start:
          {Sqlitex.Server, :start_link, ["priv/db_#{Mix.env()}.sqlite3", [name: ReplayFarm.DB]]},
        id: Sqlitex.Server
      },
      {ReplayFarm.DB, []},
      {ReplayFarm.Discord.Consumer, []},
      {Plug.Adapters.Cowboy2,
       scheme: :http,
       plug: ReplayFarm.Web.Router,
       options: [port: Application.get_env(:replay_farm, :port)]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ReplayFarm.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
