defmodule PhoenixStarterKitWeb.PageControllerTest do
  use PhoenixStarterKitWeb.ConnCase

  import PhoenixStarterKit.PartnersFixtures

  describe "GET /" do
    test "renders home page when not logged in", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "Install App"
    end

    test "redirects to settings when logged in", %{conn: conn} do
      partner = partner_fixture()
      partner_user = partner_user_fixture()
      {:ok, _} = PhoenixStarterKit.Partners.connect_partner_user(partner, partner_user)
      conn = log_in_partner_user(conn, partner_user, partner.id)

      conn = get(conn, ~p"/")
      assert redirected_to(conn) == ~p"/settings"
    end
  end
end
