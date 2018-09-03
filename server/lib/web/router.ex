defmodule ReplayFarm.Web.Router do
  @moduledoc "The web server."

  use Plug.Router
  import Plug.Conn
  import ReplayFarm.Web.Plugs
  require Logger

  alias ReplayFarm.Workers

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
      %Workers{} = w ->
        w =
          case Workers.update_worker(w, %{last_poll: System.system_time(:millisecond)}) do
            {:ok, w} ->
              w

            {:error, err} ->
              Logger.warn("updating last_poll for worker #{w.id} failed: #{inspect(err)}")
              w
          end

        case Workers.get_assigned(w) do
          {:ok, nil} ->
            send_resp(conn, 204, "")

          {:ok, job} ->
            Logger.info("sending job #{job.id} to worker #{w.id}")
            json(conn, 200, job)

          {:error, err} ->
            Logger.error("getting assigned job for worker #{w.id} failed: #{inspect(err)}")
            text(conn, 500, "couldn't get assigned job")
        end

      id ->
        if conn.private.preload_errors[:worker] === :worker_not_found do
          Logger.info("inserting new worker #{id}")

          case Workers.put_worker(id) do
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
    text(conn, 500, "TODO")
  end

  match _ do
    text(conn, 404, "not found")
  end
end
