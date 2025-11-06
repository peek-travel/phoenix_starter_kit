defmodule PhoenixStarterKitWeb.SettingsLiveTest do
  use PhoenixStarterKitWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "SettingsLive" do
    setup [:register_and_log_in_partner_user]

    test "renders settings page when authenticated", %{conn: conn, partner_user: partner_user} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      welcome_text = text_for_integration_test_element(view, "welcome-message")
      assert welcome_text =~ "Welcome!"
      assert welcome_text =~ "Test Account"
      assert welcome_text =~ partner_user.email
    end

    test "renders setting page for correct partner when there are two", %{conn: conn, partner_user: partner_user} do
      new_partner = PhoenixStarterKit.PartnersFixtures.partner_fixture(%{is_test: true, name: "New Partner"})
      {:ok, _} = PhoenixStarterKit.Partners.connect_partner_user(new_partner, partner_user)
      conn = log_in_partner_user(conn, partner_user, new_partner.id)
      {:ok, view, _html} = live(conn, ~p"/settings")

      welcome_text = text_for_integration_test_element(view, "welcome-message")
      assert welcome_text =~ "Welcome!"
      assert welcome_text =~ "Test Account"
      assert welcome_text =~ "New Partner"
      assert welcome_text =~ partner_user.email
    end

    test "redirects when not authenticated", %{conn: _conn} do
      # Create a new connection without authentication
      unauthenticated_conn = build_conn()

      assert {:error, {:redirect, %{flash: %{"error" => "You must log in to access this page."}}}} =
               live(unauthenticated_conn, ~p"/settings")
    end
  end
end
