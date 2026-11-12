defmodule PhoenixStarterKitWeb.SentryScrubberTest do
  use PhoenixStarterKitWeb.ConnCase, async: true

  import PhoenixStarterKit.PartnersFixtures

  alias PhoenixStarterKit.Partners

  test "the Sentry event of a request has no token values" do
    partner = partner_fixture()
    partner_user = partner_user_fixture()
    {:ok, _} = Partners.connect_partner_user(partner, partner_user)
    login_token = Partners.generate_embed_login_token(partner_user, partner)
    peek_auth = PeekAppSDK.Token.new_for_app_installation!(partner.app_registry_installation_refid, peek_account_user_fixture())
    header_token = PeekAppSDK.Token.new_for_app_installation!(partner.app_registry_installation_refid <> "-header")

    build_conn()
    |> put_req_header("x-peek-auth", "Bearer #{header_token}")
    |> put_req_header("x-other-header", "kept")
    |> post(~p"/peek-pro/settings?#{[login_token: login_token, auth_token: "url-auth-token"]}", %{
      "peek-auth" => peek_auth,
      "auth_token" => "body-auth-token"
    })

    event = Sentry.Event.create_event(message: "test")
    inspected = inspect(event, limit: :infinity, printable_limit: :infinity)

    assert event.request.headers["x-other-header"] == "kept"
    refute Map.has_key?(event.request.headers, "x-peek-auth")

    for value <- [login_token, peek_auth, header_token, "url-auth-token", "body-auth-token"] do
      refute inspected =~ value
    end
  end
end
