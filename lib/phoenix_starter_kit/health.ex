defmodule PhoenixStarterKit.Health do
  @moduledoc """
  The Health Context

  The HealthController exposes health and usage metrics for monitoring.

  This context fetches the info we need to answer the questions on health.
  """

  import Ecto.Query
  alias PhoenixStarterKit.Repo
  alias PhoenixStarterKit.Partners.Partner

  @doc """
  Returns a health status map.

  ## Examples

      iex> get_health_status()
      %{
        ragStatus: "green",
        publicMessage: "Operational",
        internalMessage: "All systems operational"
      }

  """
  def get_health_status do
    # For a production app, this might check for failed jobs, database connectivity,
    # external service availability, etc., and return a degraded status accordingly.
    %{
      # "<red | yellow | green>"
      ragStatus: "green",
      publicMessage: "Operational",
      internalMessage: "All systems operational"
    }
  end

  @doc """
  Returns usage metrics.

  ## Examples

      iex> get_usage_metrics()
      %{
        activePartners: 2,
        customMetrics: [],
        installedPartners: 3,
        notableEvents: []
      }

  """
  def get_usage_metrics do
    # Count installed partners (status is installed or update_installed and is_test is false)
    installed_partners_count =
      from(p in Partner,
        where:
          not is_nil(p.peek_pro_installation) and
            fragment(
              "?->>'status' = 'installed' OR ?->>'status' = 'update_installed'",
              p.peek_pro_installation,
              p.peek_pro_installation
            ) and
            p.is_test == false
      )
      |> Repo.aggregate(:count)

    # Count active partners (installed and is_test is false)
    active_partners_count =
      from(p in Partner,
        where:
          not is_nil(p.peek_pro_installation) and
            fragment(
              "?->>'status' = 'installed' OR ?->>'status' = 'update_installed'",
              p.peek_pro_installation,
              p.peek_pro_installation
            ) and
            p.is_test == false,
        distinct: p.id
      )
      |> Repo.aggregate(:count)

    %{
      activePartners: active_partners_count,
      customMetrics: [],
      installedPartners: installed_partners_count,
      notableEvents: []
    }
  end
end
