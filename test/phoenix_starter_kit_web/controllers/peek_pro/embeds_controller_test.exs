defmodule PhoenixStarterKitWeb.PeekPro.EmbedsControllerTest do
  use PhoenixStarterKitWeb.ConnCase, async: true

  import PhoenixStarterKit.PartnersFixtures

  describe "PeekPro embeds" do
    test "POST /peek-pro/settings/ shows expired when no peek_install_id", %{conn: conn} do
      conn = post(conn, ~p"/peek-pro/settings/")
      assert html_response(conn, 200) =~ "Session Expired"
    end

    test "POST /peek-pro/settings/ with valid peek_install_id but no partner shows loading", %{
      conn: conn
    } do
      peek_install_id = "install-#{System.unique_integer()}"

      account_user = peek_account_user_fixture()

      conn =
        conn
        |> assign(:peek_install_id, peek_install_id)
        |> assign(:current_partner, nil)
        |> assign(:peek_account_user, account_user)
        |> post(~p"/peek-pro/settings/")

      assert html_response(conn, 200) =~ "/peek-pro/settings/?attempt=1"
    end

    test "POST /peek-pro/settings/ increments attempt counter", %{conn: conn} do
      peek_install_id = "install-#{System.unique_integer()}"

      account_user = peek_account_user_fixture()

      conn =
        conn
        |> assign(:peek_install_id, peek_install_id)
        |> assign(:current_partner, nil)
        |> assign(:peek_account_user, account_user)
        |> post(~p"/peek-pro/settings/", %{"attempt" => "3"})

      assert html_response(conn, 200) =~ "/peek-pro/settings/?attempt=4"
    end

    test "POST /peek-pro/settings/ with valid partner logs in partner user", %{conn: conn} do
      # Create a partner first
      external_refid = "external-#{System.unique_integer()}"
      name = "Test Partner"
      install_id = "install-#{System.unique_integer()}"

      {:ok, partner} =
        PhoenixStarterKit.Partners.upsert_for_peek_pro_installation({external_refid, :peek}, name, "America/New_York")

      {:ok, partner} =
        PhoenixStarterKit.Partners.update_partner(partner, %{peek_pro_installation_id: install_id})

      account_user = peek_account_user_fixture()

      conn =
        conn
        |> assign(:peek_install_id, install_id)
        |> assign(:current_partner, partner)
        |> assign(:peek_account_user, account_user)
        |> post(~p"/peek-pro/settings/")

      # Should redirect to the home page after login
      assert redirected_to(conn) == "/settings"

      # Verify the partner user was created
      partner_user =
        account_user.email
        |> PhoenixStarterKit.Partners.get_partner_user_by_email()

      assert partner_user != nil
    end

    test "shows Safari landing page when user agent is Safari", %{conn: conn} do
      partner = PhoenixStarterKit.PartnersFixtures.partner_fixture()

      account_user = %PeekAppSDK.AccountUser{
        id: "123",
        name: "Test User",
        email: "test.user@example.com",
        is_peek_admin: true,
        primary_role: "partner_admin"
      }

      # Set Safari user agent
      conn =
        conn
        |> put_req_header(
          "user-agent",
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        )
        |> post(~p"/peek-pro/settings", %{
          "peek-auth" => PeekAppSDK.Token.new_for_app_installation!(partner.peek_pro_installation_id, account_user)
        })

      assert response(conn, 200) =~ "We Love Safari, But…"
      assert response(conn, 200) =~ "proceed-form"
      assert response(conn, 200) =~ "Open in New Tab"
      assert response(conn, 200) =~ "new-tab-form"
      assert response(conn, 200) =~ "target=\"_blank\""
      assert response(conn, 200) =~ "name=\"peek-auth\""
      assert response(conn, 200) =~ "name=\"force_proceed\" value=\"true\""
      assert response(conn, 200) =~ "try-anyway-form"
      assert response(conn, 200) =~ "handleButtonClick(event)"
    end

    test "proceeds normally when user agent is Chrome", %{conn: conn} do
      partner = PhoenixStarterKit.PartnersFixtures.partner_fixture()

      account_user = %PeekAppSDK.AccountUser{
        id: "123",
        name: "Test User",
        email: "test.user@example.com",
        is_peek_admin: true,
        primary_role: "partner_admin"
      }

      # Set Chrome user agent
      conn =
        conn
        |> put_req_header(
          "user-agent",
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        )
        |> post(~p"/peek-pro/settings", %{
          "peek-auth" => PeekAppSDK.Token.new_for_app_installation!(partner.peek_pro_installation_id, account_user)
        })

      assert redirected_to(conn) == ~p"/settings"
    end

    test "proceeds normally when Safari user has force_proceed=true", %{conn: conn} do
      partner = PhoenixStarterKit.PartnersFixtures.partner_fixture()

      account_user = %PeekAppSDK.AccountUser{
        id: "123",
        name: "Test User",
        email: "test.user@example.com",
        is_peek_admin: true,
        primary_role: "partner_admin"
      }

      # Set Safari user agent but with force_proceed
      conn =
        conn
        |> put_req_header(
          "user-agent",
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        )
        |> post(~p"/peek-pro/settings?force_proceed=true", %{
          "peek-auth" => PeekAppSDK.Token.new_for_app_installation!(partner.peek_pro_installation_id, account_user)
        })

      assert redirected_to(conn) == ~p"/settings"
    end
  end
end
