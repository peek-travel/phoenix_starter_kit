defmodule PhoenixStarterKitWeb.HealthControllerTest do
  use PhoenixStarterKitWeb.ConnCase, async: true

  import PhoenixStarterKit.PartnersFixtures

  describe "POST /health" do
    test "returns health status when checkType is health", %{conn: conn} do
      conn = post(conn, ~p"/health", %{"checkType" => "health"})

      assert json_response(conn, 200) == %{
               "ragStatus" => "green",
               "publicMessage" => "Operational",
               "internalMessage" => "All systems operational"
             }
    end

    test "returns usage information when checkType is usage", %{conn: conn} do
      # Create a partner with installed status
      _partner1 =
        partner_fixture(%{
          peek_pro_installation: %{
            status: :installed,
            display_version: "1.0.0",
            install_id: "install-1"
          },
          is_test: false
        })

      # Create a partner with installed status
      _partner2 =
        partner_fixture(%{
          peek_pro_installation: %{
            status: :installed,
            display_version: "1.0.0",
            install_id: "install-2"
          },
          is_test: false
        })

      # Create a partner with update_installed status
      _partner3 =
        partner_fixture(%{
          peek_pro_installation: %{
            status: :update_installed,
            display_version: "1.0.0",
            install_id: "install-3"
          },
          is_test: false
        })

      # Create a partner with uninstalled status
      _partner4 =
        partner_fixture(%{
          peek_pro_installation: %{
            status: :uninstalled,
            display_version: "1.0.0",
            install_id: "install-4"
          },
          is_test: false
        })

      # Create a test partner with installed status
      # This partner should not be counted in the metrics because is_test is true
      _test_partner =
        partner_fixture(%{
          peek_pro_installation: %{
            status: :installed,
            display_version: "1.0.0",
            install_id: "install-5"
          },
          is_test: true
        })

      conn = post(conn, ~p"/health", %{"checkType" => "usage"})

      response = json_response(conn, 200)
      # Only non-test partners with installed or update_installed status should be counted
      # partner1, partner2, partner3 (not partner4 or test_partner)
      assert response["installedPartners"] == 3

      # Only non-test partners with installed or update_installed status
      # partner2, partner3 (not partner1, partner4, or test_partner)
      assert response["activePartners"] == 3
      assert response["customMetrics"] == []
      assert response["notableEvents"] == []
    end
  end
end
