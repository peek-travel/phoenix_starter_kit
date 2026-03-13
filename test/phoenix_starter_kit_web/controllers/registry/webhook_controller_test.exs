defmodule PhoenixStarterKitWeb.Registry.WebhookControllerTest do
  use PhoenixStarterKitWeb.ConnCase, async: false

  alias PhoenixStarterKit.Partners

  def authenticate_peek_pro_request(ctx) do
    %{conn: conn} = ctx
    partner = PhoenixStarterKit.PartnersFixtures.partner_fixture()

    conn =
      put_req_header(conn, "x-peek-auth", "Bearer #{PeekAppSDK.Token.new_for_app_installation!(partner.app_registry_installation_refid)}")

    %{conn: conn, partner: partner}
  end

  describe "Registry webhook - on_installation_status_change" do
    setup :authenticate_peek_pro_request

    test "legacy registry: creates a partner", %{conn: conn, partner: partner} do
      PhoenixStarterKit.Repo.delete!(partner)
      external_refid = "external-#{System.unique_integer()}"
      name = "Test Partner"
      install_id = "install-#{System.unique_integer()}"

      payload = legacy_registry_payload(external_refid, name, install_id)

      conn = post(conn, ~p"/registry/api/on-installation-status-change", payload)

      assert response(conn, 200) == "Partner Test Partner updated successfully."
      partner = Partners.get_partner_by_external_id(external_refid)
      assert partner.name == name
      assert partner.app_registry_installation.status == :installed
      assert partner.app_registry_installation.display_version == "1.0.0"
      assert partner.app_registry_installation.install_id == install_id
      assert partner.platform == :peek
      assert partner.timezone == "America/Los_Angeles"
      assert partner.api_config == nil
    end

    test "legacy registry: updates an existing partner", %{conn: conn, partner: partner} do
      install_id = partner.app_registry_installation_refid

      payload =
        legacy_registry_payload(partner.external_refid, partner.name, install_id)
        |> put_in(["status"], "uninstalled")
        |> put_in(["display_version"], "2.0.0")

      conn = post(conn, ~p"/registry/api/on-installation-status-change", payload)

      assert response(conn, 200) == "Partner #{partner.name} updated successfully."
      updated_partner = Partners.get_partner_by_app_registry_install_refid(install_id)
      assert updated_partner.id == partner.id
      assert updated_partner.app_registry_installation.status == :uninstalled
      assert updated_partner.app_registry_installation.display_version == "2.0.0"
      assert updated_partner.app_registry_installation.install_id == install_id
    end

    test "legacy registry: handles is_test flag", %{conn: conn} do
      external_refid = "external-#{System.unique_integer()}"
      name = "Test Partner"
      install_id = "install-#{System.unique_integer()}"

      payload = legacy_registry_payload(external_refid, name, install_id)
      payload = put_in(payload, ["account", "is_test"], true)

      conn = post(conn, ~p"/registry/api/on-installation-status-change", payload)

      assert response(conn, 200) == "Partner Test Partner updated successfully."
      partner = Partners.get_partner_by_external_id(external_refid)
      assert partner.is_test == true
    end

    test "legacy registry: saves partner timezone", %{conn: conn} do
      external_refid = "external-#{System.unique_integer()}"
      name = "Test Partner"
      install_id = "install-#{System.unique_integer()}"

      payload = legacy_registry_payload(external_refid, name, install_id)
      payload = put_in(payload, ["account", "timezone"], "America/New_York")

      conn = post(conn, ~p"/registry/api/on-installation-status-change", payload)

      assert response(conn, 200) == "Partner Test Partner updated successfully."
      partner = Partners.get_partner_by_external_id(external_refid)
      assert partner.timezone == "America/New_York"
    end

    test "legacy registry: uses explicit platform from payload", %{conn: conn, partner: partner} do
      PhoenixStarterKit.Repo.delete!(partner)
      external_refid = "external-#{System.unique_integer()}"
      name = "Test Partner"
      install_id = "install-#{System.unique_integer()}"

      payload =
        legacy_registry_payload(external_refid, name, install_id)
        |> put_in(["account", "platform"], "acme")

      conn = post(conn, ~p"/registry/api/on-installation-status-change", payload)

      assert response(conn, 200) == "Partner Test Partner updated successfully."
      partner = Partners.get_partner_by_external_id(external_refid)
      assert partner.platform == :acme
    end

    test "registry 2.0: creates partner with api_config", %{conn: conn, partner: partner} do
      PhoenixStarterKit.Repo.delete!(partner)
      external_refid = "external-#{System.unique_integer()}"
      name = "Cross-Brand Partner"
      install_id = "install-#{System.unique_integer()}"

      payload = registry_2_payload(external_refid, name, install_id, api_url: "https://api.cng.example.com")

      conn = post(conn, ~p"/registry/api/on-installation-status-change", payload)

      assert response(conn, 200) == "Partner Cross-Brand Partner updated successfully."
      partner = Partners.get_partner_by_external_id(external_refid)
      assert partner.name == name
      assert partner.api_config.url == "https://api.cng.example.com"
      assert partner.timezone == nil
    end
  end

  describe "Registry webhook - on_booking_change" do
    setup :authenticate_peek_pro_request

    test "handles on_booking_change with valid install ID", %{conn: conn, partner: partner} do
      input = %{
        "booking_id" => "123",
        "booking" => %{
          "startsAt" => "2023-12-14T09:00:00.000000",
          "endsAt" => "2023-12-14T10:00:00.000000"
        }
      }

      conn = post(conn, ~p"/peek-pro/api/on-booking-change", input)

      assert response(conn, 200) =~ "Partner #{partner.name} received a booking change"
    end

    test "handles on_booking_change with unknown install ID", %{conn: conn, partner: partner} do
      PhoenixStarterKit.Repo.delete!(partner)

      conn =
        conn
        |> post(~p"/peek-pro/api/on-booking-change", %{
          "booking_id" => "123",
          "booking" => %{
            "startsAt" => "2023-12-14T09:00:00.000000",
            "endsAt" => "2023-12-14T10:00:00.000000"
          }
        })

      assert response(conn, 200) == "Unknown install ID"
    end
  end

  defp legacy_registry_payload(external_refid, name, install_id) do
    %{
      "account" => %{
        "id" => external_refid,
        "name" => name,
        "is_test" => false,
        "timezone" => "America/Los_Angeles"
      },
      "display_version" => "1.0.0",
      "install_id" => install_id,
      "modified_by" => %{},
      "status" => "installed"
    }
  end

  defp registry_2_payload(external_refid, name, install_id, opts) do
    api_url = Keyword.get(opts, :api_url, "https://cross-brand.example.com")
    platform = Keyword.get(opts, :platform, "peek")

    %{
      "account" => %{
        "id" => external_refid,
        "name" => name,
        "is_test" => false,
        "platform" => platform
      },
      "api" => %{
        "url" => api_url
      },
      "display_version" => "1.0.0",
      "install_id" => install_id,
      "modified_by" => %{"email" => "admin@peek.com", "name" => "Admin User"},
      "status" => "installed"
    }
  end
end
