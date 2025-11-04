defmodule PhoenixStarterKit.HealthTest do
  use PhoenixStarterKit.DataCase, async: true

  import PhoenixStarterKit.PartnersFixtures
  alias PhoenixStarterKit.Health

  describe "get_health_status/0" do
    test "returns health status" do
      assert Health.get_health_status() == %{
               ragStatus: "green",
               publicMessage: "Operational",
               internalMessage: "All systems operational"
             }
    end
  end

  describe "get_usage_metrics/0" do
    test "returns usage metrics" do
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

      metrics = Health.get_usage_metrics()

      # Only non-test partners with installed or update_installed status should be counted
      # partner1, partner2, partner3 (not partner4 or test_partner)
      assert metrics.installedPartners == 2

      # Only non-test partners with installed or update_installed status
      # partner2, partner3 (not partner1, partner4, or test_partner)
      assert metrics.activePartners == 2
      assert metrics.customMetrics == []
      assert metrics.notableEvents == []
    end
  end
end
