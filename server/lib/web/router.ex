defmodule ReplayFarm.Web.Router do
  @moduledoc "The web server."

  use Plug.Router
  use Plug.ErrorHandler
  import Plug.Conn
  import ReplayFarm.Web.Plugs
  require Logger

  alias ReplayFarm.Worker
  alias ReplayFarm.Job
  alias ReplayFarm.DB
  require DB

  plug(Plug.Logger)
  plug(Plug.Parsers, parsers: [:json], pass: ["*/*"], json_decoder: Jason)
  plug(:match)
  plug(:authenticate)
  plug(:validate)
  plug(:preload)
  plug(:dispatch)

  post "/poll" do
    w =
      Worker.get_or_put!(conn.body_params["worker"])
      |> Worker.update!(last_poll: System.system_time(:millisecond))

    case Worker.get_assigned!(w) do
      nil -> send_resp(conn, 204, "")
      j -> Logger.info("sending job #{j.id} to worker #{w.id}") && json(conn, 200, j)
    end
  end

  post "/status" do
    with %Worker{} = worker <- conn.private.preloads.worker,
         %Job{} = job <- conn.private.preloads.job do
      status = conn.body_params["status"]
      comment = conn.body_params["comment"] || job.comment

      if worker.current_job_id !== job.id do
        text(conn, 400, "worker is not assigned that job")
      else
        DB.transaction! do
          Job.update!(job, status: status, comment: comment)
          status > Job.status(:successful) && Worker.update!(worker, current_job_id: nil)
        end
      end
    else
      :error -> error(conn)
      nil -> text(conn, 400, "worker or job does not exist")
    end
  end

  match _ do
    text(conn, 404, "not found")
  end

  # Implementation for Plug.ErrorHandler: Write the generic error response.
  def handle_errors(conn, _opts) do
    error(conn)
  end
end
