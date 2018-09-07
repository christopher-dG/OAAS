defmodule ReplayFarm.Web.Router do
  @moduledoc "The web server."

  use Plug.Router
  use Plug.ErrorHandler
  import Plug.Conn
  import ReplayFarm.Web.Plugs
  require Logger

  alias ReplayFarm.Worker

  plug(Plug.Logger)
  plug(Plug.Parsers, parsers: [:json], pass: ["*/*"], json_decoder: Jason)
  plug(:match)
  plug(:authenticate)
  plug(:validate)
  plug(:preload)
  plug(:dispatch)

  # Helpers

  @doc "Starts the server (useful when running with --no-start)."
  def start do
    Plug.Adapters.Cowboy2.http(__MODULE__, port: Application.get_env(:replay_farm, :port))
  end

  # Endpoints

  post "/poll" do
    case conn.private.preloads.worker do
      nil ->
        id = conn.body_params["worker"]
        Logger.info("inserting new worker #{id}")
        Worker.put!(id: id, last_poll: System.system_time(:millisecond))
        send_resp(conn, 204, "")

      w ->
        w = Worker.update!(w, last_poll: System.system_time(:millisecond))

        case Worker.get_assigned!(w) do
          nil ->
            send_resp(conn, 204, "")

          job ->
            Logger.info("sending job #{job.id} to worker #{w.id}")
            json(conn, 200, job)
        end
    end
  end

  post "/status" do
    error(conn)
  end

  match _ do
    text(conn, 404, "not found")
  end

  # Implementation for Plug.ErrorHandler: Write the generic error response.
  def handle_errors(conn, _opts) do
    error(conn)
  end
end
