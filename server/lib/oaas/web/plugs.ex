defmodule OAAS.Web.Plugs do
  @moduledoc "Helper plugs."

  import Plug.Conn

  alias OAAS.Worker
  alias OAAS.Job
  alias OAAS.Key
  import OAAS.Utils

  @doc "Sends a text response."
  @spec text(Conn.t(), integer, String.t()) :: Conn.t()
  def text(conn, status, msg) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(status, msg)
  end

  @doc "Sends a 500 response."
  @spec error(Conn.t()) :: Conn.t()
  def error(conn) do
    text(conn, 500, "internal server error")
  end

  @doc "Sends a JSON response."
  @spec json(Conn.t(), integer, term) :: Conn.t()
  def json(conn, status, data) do
    case Jason.encode(data) do
      {:ok, encoded} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(status, encoded)

      {:error, reason} ->
        notify(:warn, "encoding HTTP response failed", reason)
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
          case Key.get(key) do
            {:ok, _k} ->
              conn

            {:error, :no_such_entity} ->
              notify(:debug, "blocked request with invalid API key `#{key}`")

              conn
              |> text(400, "invalid API key")
              |> halt()

            {:error, reason} ->
              notify(:error, "retrieving keys failed", reason)

              conn
              |> error()
              |> halt()
          end

        [] ->
          notify(:debug, "blocked request with missing API key")

          conn
          |> text(400, "missing API key")
          |> halt()

        _ ->
          notify("blocked request with invalid API key")

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
              |> text(400, "invalid request body")
              |> halt()
          end

        ["status"] ->
          case conn.body_params do
            %{"worker" => w, "job" => j, "status" => s, "comment" => c}
            when is_binary(w) and is_integer(j) and is_integer(s) and (is_binary(c) or is_nil(c)) ->
              conn

            _ ->
              conn
              |> text(400, "invalid request_body")
              |> halt()
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
    w_id = conn.body_params["worker"]
    j_id = conn.body_params["job"]

    conn
    |> put_private(:preloads, %{worker: :missing, job: :missing})
    |> (fn c ->
          if is_nil(w_id) do
            c
          else
            case Worker.get(w_id) do
              {:ok, w} -> put_private(c, :preloads, Map.put(c.private.preloads, :worker, w))
              {:error, :no_such_entity} -> :noop
              {:error, reason} -> notify(:warn, "preloading worker `#{w_id}` failed", reason)
            end
          end
        end).()
    |> (fn c ->
          if is_nil(j_id) do
            c
          else
            case Job.get(j_id) do
              {:ok, j} -> put_private(c, :preloads, Map.put(c.private.preloads, :job, j))
              {:error, :no_such_entity} -> :noop
              {:error, reason} -> notify(:warn, "preloading job `#{j_id}` failed", reason)
            end
          end
        end).()
  end
end
