defmodule ReplayFarm.Web.Router do
  @moduledoc "The web server."

  use Plug.Router
  import Plug.Conn
  import ReplayFarm.Web.Plugs
  require Logger

  alias ReplayFarm.Worker
  alias ReplayFarm.Job

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
    case conn.body_params["worker"] do
      %Worker{} = w ->
        w =
          case Worker.update(w, last_poll: System.system_time(:millisecond)) do
            {:ok, w} ->
              w

            {:error, err} ->
              Logger.warn("updating last_poll for worker #{w.id} failed: #{inspect(err)}")
              w
          end

        case Worker.get_assigned(w) do
          {:ok, nil} ->
            send_resp(conn, 204, "")

          {:ok, %Job{} = job} ->
            Logger.info("sending job #{job.id} to worker #{w.id}")
            json(conn, 200, job)

          {:error, err} ->
            Logger.error("getting assigned job for worker #{w.id} failed: #{inspect(err)}")
            text(conn, 500, "couldn't get assigned job")
        end

      id ->
        if conn.private.preload_errors.worker === :worker_not_found do
          Logger.info("inserting new worker #{id}")

          case Worker.put(id: id, last_poll: System.system_time(:millisecond)) do
            {:ok, _w} ->
              send_resp(conn, 204, "")

            {:error, err} ->
              Logger.error("creating new worker #{id} failed: #{inspect(err)}")
              text(conn, 500, "couldn't create new worker")
          end
        else
          text(conn, 500, "couldn't retrieve worker")
        end
    end
  end

  post "/status" do
    case conn.body_params do
      %{
        "worker" => %Worker{} = worker,
        "job" => %Job{} = job,
        "status" => status,
        "comment" => comment
      } ->
        if worker.current_job_id != job.id do
          text(conn, 400, "worker is not assigned that job")
        else
          text(conn, 500, "TODO")
        end

      _ ->
        errs = conn.private.preload_errors

        cond do
          errs.worker === :worker_not_found -> text(conn, 400, "worker does not exist")
          errs.job === :job_not_found -> text(conn, 400, "job does not exist")
          true -> text(conn, 500, "couldn't look up required resources")
        end
    end
  end

  match _ do
    text(conn, 404, "not found")
  end
end
