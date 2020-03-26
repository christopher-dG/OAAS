defmodule OAAS.Application do
  @moduledoc false

  alias OAAS.DB
  use Application

  def start(_type, _args) do
    db = DB.db_path()
    dir = Path.dirname(db)
    File.mkdir_p(dir)

    children = [
      %{
        start: {Sqlitex.Server, :start_link, [db, [name: OAAS.DB]]},
        id: Sqlitex.Server
      },
      OAAS.DB,
      OAAS.Queue,
      OAAS.Discord,
      OAAS.Reddit,
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: OAAS.Web.Router,
        options: [port: Application.fetch_env!(:oaas, :port)]
      )
    ]

    opts = [strategy: :one_for_one, name: OAAS.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
