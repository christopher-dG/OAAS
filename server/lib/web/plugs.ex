defmodule ReplayFarm.Web.Plugs do
  @moduledoc "Helper plugs."

  import Plug.Conn
  require Logger

  alias ReplayFarm.Workers
  alias ReplayFarm.Jobs

  @doc "Sends a text response."
  def text(conn, status, text) when is_integer(status) and is_binary(text) do
    conn |> put_resp_content_type("text/plain") |> send_resp(status, text)
  end

  @doc "Sends a JSON response."
  def json(conn, status, data) when is_integer(status) do
    case Jason.encode(data) do
      {:ok, encoded} ->
        conn |> put_resp_content_type("application/json") |> send_resp(status, encoded)

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
                conn |> text(400, "invalid API key") |> halt()
              end

            {:error, err} ->
              Logger.error("retrieving keys failed: #{inspect(err)}")
              conn |> text(500, "couldn't check API key") |> halt()
          end

        [] ->
          conn |> text(400, "missing API key") |> halt()

        _ ->
          conn |> text(400, "invalid API key") |> halt()
      end
    end
  end

  @doc "Validates the request body."
  def validate(conn, _opts) do
    if conn.method === "POST" do
      case conn.path_info do
        ["poll"] ->
          case conn.body_params do
            %{"worker" => w} when is_binary(w) -> conn
            _ -> conn |> text(400, "invalid request body") |> halt()
          end

        ["status"] ->
          case conn.body_params do
            %{"worker" => w, "job" => j, "status" => s, "comment" => c}
            when is_binary(w) and is_integer(j) and is_integer(s) and is_binary(c) ->
              conn

            _ ->
              conn |> text(400, "invalid request_body") |> halt()
          end

        _ ->
          conn
      end
    else
      conn
    end
  end

  @doc "Preloads parameters passed as IDs into their actual entities."
  def preload(conn, _opts) do
    w = conn.body_params["worker"]
    j = conn.body_params["job"]

    conn = put_private(conn, :preload_errors, %{})

    conn =
      unless is_nil(w) do
        case Workers.get_worker(w) do
          {:ok, worker} ->
            Logger.debug("preloaded worker #{w}")
            %{conn | body_params: %{conn.body_params | "worker" => worker}}

          {:error, err} ->
            Logger.warn("preloading worker #{w} failed: #{inspect(err)}")
            put_private(conn, :preload_errors, Map.put(conn.private.preload_errors, :worker, err))
        end
      else
        conn
      end

    conn =
      unless is_nil(j) do
        case Jobs.get_job(j) do
          {:ok, job} ->
            Logger.debug("preloaded job #{j}")
            %{conn | body_params: %{conn.body_params | "job" => job}}

          {:error, err} ->
            Logger.warn("preloading job #{j} failed: #{inspect(err)}")
            put_private(conn, :preload_errors, Map.put(conn.private.preload_errors, :job, err))
        end
      else
        conn
      end

    conn
  end
end
