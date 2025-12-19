defmodule PhoenixStarterKitWeb.PeekPro.WebhookController do
  @moduledoc """
  This controller handles webhooks from PeekPro.

  It receives installation status change notifications and updates the partner
  record accordingly.
  """
  use PhoenixStarterKitWeb, :controller

  alias PhoenixStarterKit.Partners

  @doc """
  Handles the installation status change webhook from PeekPro.

  This webhook is sent when the installation status of the app changes.
  It updates the partner record in the database with the new status and
  version information and is where you can update anything specific that you
  want to have happen when the app is installed or uninstalled;

  see the `on_installed/1` and `on_uninstalled/1` functions below.
  """
  def on_installation_status_change(conn, params) do
    partner = do_upsert_partner!(params)

    if partner.peek_pro_installation.status == :uninstalled, do: on_uninstalled(partner)
    if partner.peek_pro_installation.status == :installed, do: on_installed(partner)

    send_resp(conn, :ok, "Partner #{partner.name} updated successfully.")
  end

  defp do_upsert_partner!(raw_params) do
    %{
      "account" =>
        %{
          "id" => external_refid,
          "name" => name,
          "is_test" => is_test,
          "timezone" => timezone
        } = account,
      "display_version" => display_version,
      "install_id" => install_id,
      "modified_by" => %{},
      "status" => status
    } = raw_params

    # Old registry isn't sending a platform, new one is. Default to peek as old
    # registry apps are only peek.
    platform = Map.get(account, "platform", "peek")

    # 1. Ensure we have a partner in our DB; first-time install will insert.
    {:ok, partner} =
      Partners.upsert_for_peek_pro_installation({external_refid, platform}, name, timezone)

    # 2. Ensure it matches the state we just received
    {:ok, partner} =
      Partners.update_partner(partner, %{
        peek_pro_installation_id: install_id,
        peek_pro_installation: %{
          status: status,
          display_version: display_version,
          install_id: install_id
        },
        is_test: is_test
      })

    partner
  end

  # These are great places to "do things"; for the uninstall case you might want
  # to clear out an API key, delete some records, let another system know, etc.
  defp on_uninstalled(partner) do
    PeekAppSDK.Metrics.track_uninstall(partner)
  end

  defp on_installed(partner) do
    PeekAppSDK.Metrics.track_install(partner)
  end

  @doc """
  Handles the booking change webhook from PeekPro.

  This webhook is sent when a booking is created or updated.
  It's a good place to update your local booking record or
  do whatever else you need to do when a booking changes.

  Notice that we use the `peek_install_id` to look up the partner, this is set
  w/ a plug after authenticating the request.
  """
  def on_booking_change(conn, params) do
    %{
      assigns: %{
        peek_install_id: peek_install_id
      }
    } = conn

    case Partners.get_partner_by_peek_install_id(peek_install_id) do
      nil ->
        send_resp(conn, :ok, "Unknown install ID")

      partner ->
        # This is how you can send tracking events for important happenings:
        # PeekAppSDK.Metrics.track(partner, "booking.changed", %{"test_event_property": "test_value"})
        send_resp(conn, :ok, "Partner #{partner.name} received a booking change: #{inspect(params)}")
    end
  end
end
