defmodule PhoenixStarterKitWeb.Plugs.ContentSecurityPolicyTest do
  use PhoenixStarterKitWeb.ConnCase, async: false

  import PhoenixStarterKit.PartnersFixtures

  alias PhoenixStarterKitWeb.Plugs.ContentSecurityPolicy

  @policy "base-uri 'self'; frame-ancestors 'self' https://*.peek.com https://*.peeklabs.com"

  test ":browser pipeline sets the policy", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert get_resp_header(conn, "content-security-policy") == [@policy]
  end

  test ":peek_pro_embed pipeline sets the policy", %{conn: conn} do
    conn = post(conn, ~p"/peek-pro/settings")

    assert get_resp_header(conn, "content-security-policy") == [@policy]
  end

  test ":webhook pipeline sets the policy", %{conn: conn} do
    conn = post(conn, ~p"/peek-pro/api/on-booking-change", %{})

    assert get_resp_header(conn, "content-security-policy") == [@policy]
  end

  test ":install_webhook pipeline sets the policy", %{conn: conn} do
    partner = partner_fixture()
    install_id = partner.app_registry_installation_refid

    payload = %{
      "account" => %{"id" => partner.external_refid, "name" => partner.name, "is_test" => false},
      "display_version" => "1.0.0",
      "install_id" => install_id,
      "modified_by" => %{},
      "status" => "installed"
    }

    conn =
      conn
      |> put_req_header("x-peek-auth", "Bearer #{PeekAppSDK.Token.new_for_app_installation!(install_id)}")
      |> post(~p"/registry/api/on-installation-status-change", payload)

    assert response(conn, 200)
    assert get_resp_header(conn, "content-security-policy") == [@policy]
  end

  test "uses the configured frame ancestors" do
    previous = Application.fetch_env!(:phoenix_starter_kit, :frame_ancestors)
    on_exit(fn -> Application.put_env(:phoenix_starter_kit, :frame_ancestors, previous) end)
    Application.put_env(:phoenix_starter_kit, :frame_ancestors, ["https://app.example.com"])

    conn = ContentSecurityPolicy.call(build_conn(), ContentSecurityPolicy.init([]))

    assert get_resp_header(conn, "content-security-policy") == ["base-uri 'self'; frame-ancestors 'self' https://app.example.com"]
  end
end
