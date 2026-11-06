defmodule PhoenixStarterKitWeb.HealthController do
  @moduledoc """
  Answers `POST /health`.

  `checkType=health` needs no token.
  `checkType=usage` needs a valid Peek auth token, else it returns 401.
  `PeekAppSDK.Plugs.PeekAuth.set_peek_install_id/2` reads the token from a `peek-auth`
  body or query param, or from an `x-peek-auth: Bearer <token>` header.
  The usage counts are totals for all partners. Any install's valid token unlocks them.
  """
  use PhoenixStarterKitWeb, :controller

  alias PhoenixStarterKit.Health

  def index(conn, %{"checkType" => "health"}) do
    response = Health.get_health_status()
    json(conn, response)
  end

  def index(%{assigns: %{peek_install_id: peek_install_id}} = conn, %{"checkType" => "usage"}) when is_binary(peek_install_id) do
    response = Health.get_usage_metrics()
    json(conn, response)
  end

  def index(conn, %{"checkType" => "usage"}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Unauthorized"})
  end
end
