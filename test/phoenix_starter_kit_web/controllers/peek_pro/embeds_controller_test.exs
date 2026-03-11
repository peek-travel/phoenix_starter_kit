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

    test "POST /peek-pro/settings/ with valid partner redirects with auth token", %{conn: conn} do
      # Create a partner first
      external_refid = "external-#{System.unique_integer()}"
      name = "Test Partner"
      install_id = "install-#{System.unique_integer()}"

      {:ok, partner} =
        PhoenixStarterKit.Partners.upsert_for_app_registry_installation(install_id, %{
          external_refid: external_refid,
          platform: :peek,
          name: name,
          timezone: "America/New_York"
        })

      account_user = peek_account_user_fixture()

      conn =
        conn
        |> assign(:peek_install_id, install_id)
        |> assign(:current_partner, partner)
        |> assign(:peek_account_user, account_user)
        |> post(~p"/peek-pro/settings/")

      # Should redirect to settings with an auth_token
      redirect_url = redirected_to(conn)
      assert redirect_url =~ "/settings?auth_token="

      # Verify the partner user was created
      partner_user =
        account_user.email
        |> PhoenixStarterKit.Partners.get_partner_user_by_email()

      assert partner_user != nil
    end

    test "redirects with auth token regardless of browser (Safari, Chrome, etc)", %{conn: conn} do
      partner = PhoenixStarterKit.PartnersFixtures.partner_fixture()

      account_user = %PeekAppSDK.AccountUser{
        id: "123",
        name: "Test User",
        email: "safari.test@example.com",
        is_peek_admin: true,
        primary_role: "partner_admin"
      }

      # Safari user agent — should no longer show a landing page
      conn =
        conn
        |> put_req_header(
          "user-agent",
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        )
        |> post(~p"/peek-pro/settings", %{
          "peek-auth" => PeekAppSDK.Token.new_for_app_installation!(partner.app_registry_installation_refid, account_user)
        })

      redirect_url = redirected_to(conn)
      assert redirect_url =~ "/settings?auth_token="
    end

    test "auth token in redirect is a valid Phoenix.Token", %{conn: conn} do
      partner = PhoenixStarterKit.PartnersFixtures.partner_fixture()

      account_user = %PeekAppSDK.AccountUser{
        id: "456",
        name: "Token User",
        email: "token.test@example.com",
        is_peek_admin: false,
        primary_role: "partner_admin"
      }

      conn =
        conn
        |> put_req_header(
          "user-agent",
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        )
        |> post(~p"/peek-pro/settings", %{
          "peek-auth" => PeekAppSDK.Token.new_for_app_installation!(partner.app_registry_installation_refid, account_user)
        })

      redirect_url = redirected_to(conn)
      %URI{query: query} = URI.parse(redirect_url)
      %{"auth_token" => token} = URI.decode_query(query)

      assert {:ok, {partner_user_id, partner_id}} =
               Phoenix.Token.verify(PhoenixStarterKitWeb.Endpoint, "partner_auth", token, max_age: 86_400)

      assert is_binary(partner_user_id)
      assert partner_id == partner.id
    end
  end
end
