defmodule OAAS.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: OAAS.Worker.start_link(arg)
      %{
        start:
          {Sqlitex.Server, :start_link, ["priv/db_#{Mix.env()}.sqlite3", [name: OAAS.DB]]},
        id: Sqlitex.Server
      },
      OAAS.DB,
      OAAS.Queue,
      OAAS.Discord,
      # OAAS.Reddit,
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: OAAS.Web.Router,
        options: [port: Application.get_env(:oaas, :port)]
      )
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OAAS.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
