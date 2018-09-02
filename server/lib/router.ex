defmodule ReplayFarm.Router do
  @moduledoc "The web server."

  use Plug.Router
  import Plug.Conn
  require Logger

  alias ReplayFarm.Worker

  plug(Plug.Logger)
  plug(Plug.Parsers, parsers: [:json], pass: ["*/*"], json_decoder: Jason)
  plug(:match)
  plug(:authenticate)
  plug(:validate)
  plug(:dispatch)

  # Helpers

  @doc "Starts the server (useful when running with --no-start)."
  def start do
    Plug.Adapters.Cowboy2.http(__MODULE__, port: Application.get_env(:replay_farm, :port))
  end

  # Plugs

  @doc "Sends a text response."
  def text(conn, status, text) when is_integer(status) and is_binary(text) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(status, text)
  end

  @doc "Sends a JSON response."
  def json(conn, status, data) when is_integer(status) do
    case Jason.encode(data) do
      {:ok, encoded} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(status, encoded)

      {:error, err} ->
        Logger.error("encoding response failed: #{inspect(err)}")
        text(conn, 500, "couldn't encode response")
    end
  end

  @doc "Authenticates a request with an API key."
  def authenticate(conn, _opts) do
    if Mix.env() === :dev do
      # Don't worry about auth for development.
      conn
    else
      case get_req_header(conn, "authorization") do
        [key] ->
          case ReplayFarm.Keys.get_keys() do
            {:ok, keys} ->
              if key in keys do
                conn
              else
                conn
                |> text(400, "invalid API key")
                |> halt()
              end

            {:error, err} ->
              Logger.error("retrieving keys failed: #{inspect(err)}")

              conn
              |> text(500, "couldn't check API key")
              |> halt()
          end

        [] ->
          conn
          |> text(400, "missing API key")
          |> halt()

        _ ->
          conn
          |> text(400, "invalid API key")
          |> halt()
      end
    end
  end

  @doc "Validates the request body."
  def validate(conn, _opts) do
    if conn.method === "POST" do
      case conn.path_info do
        ["poll"] ->
          case conn.body_params do
            %{"worker" => w} when is_binary(w) ->
              conn

            _ ->
              conn
              |> send_resp(400, "invalid request body")
              |> halt()
          end

        ["status"] ->
          case conn.body_params do
            %{"worker" => w, "job" => j, "status" => s, "comment" => c}
            when is_binary(w) and is_integer(j) and is_integer(s) and is_binary(c) ->
              conn

            _ ->
              conn
              |> send_resp(400, "invalid request_body")
              |> halt()
          end

        _ ->
          conn
      end
    else
      conn
    end
  end

  # Endpoints

  post "/poll" do
    id = conn.body_params["worker"]

    case Worker.get_worker(id) do
      {:ok, worker} ->
        worker =
          case Worker.update_worker(worker, %{
                 worker
                 | last_poll: System.system_time(:millisecond)
               }) do
            {:ok, w} ->
              w

            {:error, err} ->
              Logger.warn("updating last_poll for worker #{id} failed: #{inspect(err)}")
              worker
          end

        case Worker.get_assigned(worker) do
          {:ok, nil} ->
            send_resp(conn, 204, "")

          {:ok, job} ->
            json(conn, 200, job)
        end

      {:error, :worker_not_found} ->
        Logger.info("inserting new worker #{id}")

        case Worker.put_worker(id) do
          {:ok, _w} ->
            send_resp(conn, 204, "")

          {:error, err} ->
            Logger.error("creating new worker #{id} failed: #{inspect(err)}")
            text(conn, 500, "couldn't create new worker")
        end

      {:error, err} ->
        Logger.error("getting assigned job for worker #{id} failed: #{inspect(err)}")
        text(conn, 500, "couldn't get assigned job")
    end
  end

  post "/status" do
    text(conn, 500, "TODO")
  end

  match _ do
    text(conn, 404, "not found")
  end
end
