defmodule PhoenixStarterKitWeb.PeekPro.WebhookControllerTest do
  use PhoenixStarterKitWeb.ConnCase, async: false

  alias PhoenixStarterKit.Partners

  def authenticate_peek_pro_request(ctx) do
    %{conn: conn} = ctx
    partner = PhoenixStarterKit.PartnersFixtures.partner_fixture()
    conn = put_req_header(conn, "x-peek-auth", "Bearer #{PeekAppSDK.Token.new_for_app_installation!(partner.peek_pro_installation_id)}")
    %{conn: conn, partner: partner}
  end

  describe "PeekPro webhook - on_installation_status_change" do
    setup :authenticate_peek_pro_request

    test "creates a partner when it doesn't exist", %{conn: conn, partner: partner} do
      PhoenixStarterKit.Repo.delete!(partner)
      external_refid = "external-#{System.unique_integer()}"
      name = "Test Partner"
      install_id = "install-#{System.unique_integer()}"

      payload = peek_pro_installation_webhook_payload(external_refid, name, install_id)

      conn = post(conn, ~p"/peek-pro/api/on-installation-status-change", payload)

      assert response(conn, 200) == "Partner Test Partner updated successfully."
      partner = Partners.get_partner_by_external_id(external_refid)
      assert partner.name == name
      assert partner.external_refid == external_refid
      assert partner.peek_pro_installation_id == install_id
      assert partner.peek_pro_installation.status == :installed
      assert partner.peek_pro_installation.display_version == "1.0.0"
      assert partner.peek_pro_installation.install_id == install_id
    end

    test "updates a partner when it exists", %{conn: conn} do
      # Create a partner first
      external_refid = "external-#{System.unique_integer()}"
      name = "Test Partner"
      install_id = "install-#{System.unique_integer()}"

      {:ok, partner} = Partners.upsert_for_peek_pro_installation(external_refid, name, "America/New_York")

      # Now update it with a new installation status
      payload =
        peek_pro_installation_webhook_payload(
          external_refid,
          name,
          install_id,
          "uninstalled",
          "2.0.0"
        )

      conn = post(conn, ~p"/peek-pro/api/on-installation-status-change", payload)

      assert response(conn, 200) == "Partner Test Partner updated successfully."
      updated_partner = Partners.get_partner_by_external_id(external_refid)
      assert updated_partner.id == partner.id
      assert updated_partner.peek_pro_installation.status == :uninstalled
      assert updated_partner.peek_pro_installation.display_version == "2.0.0"
      assert updated_partner.peek_pro_installation.install_id == install_id
    end

    test "handles is_test flag", %{conn: conn} do
      external_refid = "external-#{System.unique_integer()}"
      name = "Test Partner"
      install_id = "install-#{System.unique_integer()}"

      payload = peek_pro_installation_webhook_payload(external_refid, name, install_id)
      payload = put_in(payload, ["account", "is_test"], true)

      conn = post(conn, ~p"/peek-pro/api/on-installation-status-change", payload)

      assert response(conn, 200) == "Partner Test Partner updated successfully."
      partner = Partners.get_partner_by_external_id(external_refid)
      assert partner.is_test == true
    end

    test "saves partner timezone from webhook payload", %{conn: conn} do
      external_refid = "external-#{System.unique_integer()}"
      name = "Test Partner"
      install_id = "install-#{System.unique_integer()}"

      payload = peek_pro_installation_webhook_payload(external_refid, name, install_id)
      payload = put_in(payload, ["account", "timezone"], "America/New_York")

      conn = post(conn, ~p"/peek-pro/api/on-installation-status-change", payload)

      assert response(conn, 200) == "Partner Test Partner updated successfully."
      partner = Partners.get_partner_by_external_id(external_refid)
      assert partner.timezone == "America/New_York"
    end
  end

  describe "PeekPro webhook - on_booking_change" do
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

  # Helper function to create a webhook payload
  defp peek_pro_installation_webhook_payload(
         external_refid,
         name,
         install_id,
         status \\ "installed",
         display_version \\ "1.0.0"
       ) do
    %{
      "account" => %{
        "id" => external_refid,
        "name" => name,
        "is_test" => false,
        "timezone" => "America/New_York"
      },
      "display_version" => display_version,
      "install_id" => install_id,
      "modified_by" => %{},
      "status" => status
    }
  end
end
