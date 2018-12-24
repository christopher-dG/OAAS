defmodule OAAS.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      %{
        start: {Sqlitex.Server, :start_link, ["priv/db_#{Mix.env()}.sqlite3", [name: OAAS.DB]]},
        id: Sqlitex.Server
      },
      OAAS.DB,
      OAAS.Queue,
      OAAS.Discord,
      OAAS.Reddit,
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: OAAS.Web.Router,
        options: [port: Application.get_env(:oaas, :port)]
      )
    ]

    opts = [strategy: :one_for_one, name: OAAS.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
