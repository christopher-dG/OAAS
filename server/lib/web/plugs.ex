defmodule ReplayFarm.Web.Plugs do
  @moduledoc "Helper plugs."

  import Plug.Conn
  require Logger

  alias ReplayFarm.Worker
  alias ReplayFarm.Job
  alias ReplayFarm.Key

  @doc "Sends a text response."
  def text(conn, status, text) when is_integer(status) and is_binary(text) do
    conn |> put_resp_content_type("text/plain") |> send_resp(status, text)
  end

  @doc "Sends a 500 response."
  def error(conn) do
    text(conn, 500, "internal server error")
  end

  @doc "Sends a JSON response."
  def json(conn, status, data) when is_integer(status) do
    case Jason.encode(data) do
      {:ok, encoded} ->
        conn |> put_resp_content_type("application/json") |> send_resp(status, encoded)

      {:error, err} ->
        Logger.error("encoding response failed: #{inspect(err)}")
        error(conn)
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
          try do
            if key in Key.get!() do
              conn
            else
              conn |> text(400, "invalid API key") |> halt()
            end
          rescue
            e -> Logger.info("getting keys failed: #{inspect(e)}") && conn |> error() |> halt()
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

    conn = put_private(conn, :preloads, %{worker: nil, job: nil})

    conn =
      if is_nil(w) do
        conn
      else
        try do
          worker = Worker.get!(w)
          put_private(conn, :preloads, %{conn.private.preloads | worker: worker})
        rescue
          e -> Logger.info("preloading worker #{w} failed: #{inspect(e)}") && conn
        end
      end

    conn =
      if is_nil(j) do
        conn
      else
        try do
          job = Job.get!(j)
          put_private(conn, :preloads, %{conn.private.preloads | job: job})
        rescue
          e -> Logger.info("preloading job #{j} failed: #{inspect(e)}") && conn
        end
      end

    conn
  end
end
