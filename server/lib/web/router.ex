defmodule ReplayFarm.Web.Router do
  use Plug.Router
  import Plug.Conn
  require Logger

  plug(:match)
  plug(Plug.Logger)
  plug(:auth)
  plug(:dispatch)

  @doc "Authenticates a request with an admin API key."
  def auth(conn, _opts) do
    if Mix.env() === :dev do
      # Don't worry about auth for development.
      true
    else
      f =
        if String.contains?(conn.request_path, "/admin") do
          &ReplayFarm.DB.Keys.get_admin_keys/0
        else
          &ReplayFarm.DB.Keys.get_worker_keys/0
        end

      case f.() do
        {:ok, keys} ->
          case get_req_header(conn, "authorization") do
            [] ->
              conn
              |> send_resp(400, "missing API key")
              |> halt()

            [key] ->
              if key in keys do
                conn
              else
                conn
                |> send_resp(400, "invalid API key")
                |> halt()
              end

            _ ->
              conn
              |> send_resp(400, "invalid API key")
              |> halt()
          end

        {:error, err} ->
          Logger.error("retrieving keys failed: #{inspect(err)}")

          conn
          |> send_resp(500, "internal server error")
          |> halt()
      end
    end
  end

  post "/poll" do
    send_resp(conn, 204, "no new job")
  end

  post "/admin/keys" do
    send_resp(conn, 500, "TODO")
  end

  match _ do
    send_resp(conn, 404, "not found")
  end
end
