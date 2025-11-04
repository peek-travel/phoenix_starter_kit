defmodule PhoenixStarterKitWeb.HealthController do
  use PhoenixStarterKitWeb, :controller

  alias PhoenixStarterKit.Health

  def index(conn, %{"checkType" => "health"}) do
    response = Health.get_health_status()
    json(conn, response)
  end

  def index(conn, %{"checkType" => "usage"}) do
    response = Health.get_usage_metrics()
    json(conn, response)
  end
end
