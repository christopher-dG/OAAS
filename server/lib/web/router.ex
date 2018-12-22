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
      conn.body_params["worker"]
      |> Worker.get_or_put!()
      |> Worker.update!(last_poll: System.system_time(:millisecond))

    case Worker.get_assigned!(w) do
      nil -> send_resp(conn, 204, "")
      j -> Logger.info("Sending job #{j.id} to worker #{w.id}") && json(conn, 200, j)
    end
  end

  post "/status" do
    with %Worker{} = w <- conn.private.preloads.worker,
         %Job{} = j <- conn.private.preloads.job do
      status = conn.body_params["status"]
      comment = conn.body_params["comment"] || j.comment

      if w.current_job_id !== j.id do
        text(conn, 400, "worker is not assigned that job")
      else
        DB.transaction! do
          Job.update!(j, status: status, comment: comment)
          Job.finished(status) && Worker.update!(w, current_job_id: nil)
        end

        Logger.info(
          "Job `#{j.id}` updated to status `#{Job.status(status)}` by worker `#{w.id}`."
        )

        send_resp(conn, 204, "")
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
