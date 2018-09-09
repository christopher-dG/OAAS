defmodule ReplayFarm do
  @moduledoc false

  @doc "Starts the database and server (useful when running with --no-start)."
  @spec start :: {:ok, map} | {:error, term}
  def start do
    with :ok <- File.mkdir_p("priv"),
         {:ok, _} <-
           Sqlitex.Server.start_link("priv/db_#{Mix.env()}.sqlite3", name: ReplayFarm.DB),
         {:ok, _} <- ReplayFarm.DB.start_link([]),
         {:ok, _} <-
           Plug.Adapters.Cowboy2.http(ReplayFarm.Web.Router,
             port: Application.get_env(:replay_farm, :port)
           ) do
      :ok
    else
      {:error, err} -> {:error, err}
    end
  end
end
