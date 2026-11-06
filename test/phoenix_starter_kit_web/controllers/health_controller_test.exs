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

    test "returns health status when checkType is health and the x-peek-auth token does not verify", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-peek-auth", "Bearer not-a-valid-token")
        |> post(~p"/health", %{"checkType" => "health"})

      assert %{"ragStatus" => "green"} = json_response(conn, 200)
    end

    test "returns 401 and no partner counts for usage without an x-peek-auth token", %{conn: conn} do
      partner_fixture(%{
        app_registry_installation: %{status: :installed, display_version: "1.0.0", install_id: "install-1"},
        is_test: false
      })

      conn = post(conn, ~p"/health", %{"checkType" => "usage"})

      assert json_response(conn, 401) == %{"error" => "Unauthorized"}
    end

    test "returns 401 for usage with a token that does not verify", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-peek-auth", "Bearer not-a-valid-token")
        |> post(~p"/health", %{"checkType" => "usage"})

      assert json_response(conn, 401) == %{"error" => "Unauthorized"}
    end

    test "returns usage information when checkType is usage and the x-peek-auth token is valid", %{conn: conn} do
      # Create a partner with installed status
      _partner1 =
        partner_fixture(%{
          app_registry_installation: %{
            status: :installed,
            display_version: "1.0.0",
            install_id: "install-1"
          },
          is_test: false
        })

      # Create a partner with installed status
      _partner2 =
        partner_fixture(%{
          app_registry_installation: %{
            status: :installed,
            display_version: "1.0.0",
            install_id: "install-2"
          },
          is_test: false
        })

      # Create a partner with update_installed status
      _partner3 =
        partner_fixture(%{
          app_registry_installation: %{
            status: :update_installed,
            display_version: "1.0.0",
            install_id: "install-3"
          },
          is_test: false
        })

      # Create a partner with uninstalled status
      _partner4 =
        partner_fixture(%{
          app_registry_installation: %{
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
          app_registry_installation: %{
            status: :installed,
            display_version: "1.0.0",
            install_id: "install-5"
          },
          is_test: true
        })

      conn =
        conn
        |> put_req_header("x-peek-auth", "Bearer #{PeekAppSDK.Token.new_for_app_installation!("install-1")}")
        |> post(~p"/health", %{"checkType" => "usage"})

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
