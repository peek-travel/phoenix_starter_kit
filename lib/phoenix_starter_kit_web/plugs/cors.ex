defmodule PhoenixStarterKitWeb.Plugs.CORS do
  @moduledoc """
  A plug to handle CORS (Cross-Origin Resource Sharing) headers for API endpoints.

  This plug adds the necessary CORS headers to allow cross-origin requests
  from web browsers, which is essential for widget endpoints that are called
  from external domains.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, DELETE, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "*")
    |> put_resp_header("access-control-max-age", "86400")
  end
end
