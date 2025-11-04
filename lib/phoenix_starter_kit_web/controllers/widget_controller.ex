defmodule PhoenixStarterKitWeb.Widget.WidgetController do
  @moduledoc """

  This controller handles widget API requests for the PhoenixStarterKit application.

  It provides endpoints for checking anything with client authentication.
  """
  use PhoenixStarterKitWeb, :controller

  @doc """
  Sample call
  """
  def your_end_point(%{assigns: %{peek_install_id: _peek_install_id}} = conn, _params) do
    json(conn, %{
      ok: "true",
      message: "Hello from PhoenixStarterKit"
    })
  end

  def your_end_point(conn, _params) do
    conn
    |> put_status(401)
    |> json(%{error: "Unauthorized"})
  end

  @doc """
  Handles OPTIONS requests for CORS preflight.
  """
  def options(conn, _params) do
    # The CORS plug will handle the headers, we just need to return 200
    send_resp(conn, 200, "")
  end
end
