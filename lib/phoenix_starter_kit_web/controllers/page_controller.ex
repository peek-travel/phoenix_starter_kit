defmodule PhoenixStarterKitWeb.PageController do
  use PhoenixStarterKitWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_partner_user] do
      redirect(conn, to: ~p"/settings")
    else
      render(conn, :home)
    end
  end
end
