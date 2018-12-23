defmodule ReplayFarm.Web.Router do
  @moduledoc """
  The web server.

  See the docstrings in ReplayFarm.Web.Plugs for some conventions.
  """

  use Plug.Router
  use Plug.ErrorHandler
  import Plug.Conn
  import ReplayFarm.Web.Plugs

  alias ReplayFarm.Worker
  alias ReplayFarm.Job
  alias ReplayFarm.DB
  import ReplayFarm.Utils
  require DB

  plug(Plug.Logger)
  plug(Plug.Parsers, parsers: [:json], pass: ["*/*"], json_decoder: Jason)
  plug(:match)
  plug(:authenticate)
  plug(:validate)
  plug(:preload)
  plug(:dispatch)

  post "/poll" do
    id = conn.body_params["worker"]

    with {:ok, w} <- Worker.get_or_put(id),
         {:ok, w} <- Worker.update(w, last_poll: System.system_time(:millisecond)),
         {:ok, j} <- Worker.get_assigned(w) do
      case j do
        nil ->
          send_resp(conn, 204, "")

        j ->
          json(conn, 200, j)
      end
    else
      {:error, err} -> notify(:warn, "polling response for worker `#{id}` failed", err)
    end
  end

  post "/status" do
    with %Worker{} = w <- conn.private.preloads.worker,
         %Job{} = j <- conn.private.preloads.job do
      status = conn.body_params["status"]
      comment = conn.body_params["comment"] || j.comment

      if w.current_job_id === j.id do
        case Job.update_status(j, w, status, comment) do
          {:ok, j} ->
            notify(
              "job `#{j.id}` updated to status `#{Job.status(j.status)}` by worker `#{w.id}`"
            )

            send_resp(conn, 204, "")

          {:error, err} ->
            notify(:error, "updating status for job `#{j.id}` failed", err)
            error(conn)
        end
      else
        notify(
          :warn,
          "Worker `#{w.id}` tried to update job `#{j.id}`, but is assigned job `#{
            w.current_job_id
          }`"
        )

        text(conn, 400, "worker is not assigned that job")
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
