defmodule PhoenixStarterKit.Platforms.PeekPro do
  @moduledoc """
  PeekPro-specific implementation of partner account operations.

  All external GET/CREATE calls into a PeekPro-backed partner account live here.
  Higher-level code should go through `PhoenixStarterKit.Platforms`, which delegates to
  this module when `partner.platform == :peek`.
  """

  alias PeekAppSDK.Client
  alias PhoenixStarterKit.Partners.Partner

  @doc """
  Gets activities for a partner.
  """
  def get_activities(%Partner{} = partner) do
    query = """
    query GetActivities {
      activities(filter: {mode: ACTIVITY}) {
        name
        colorHex
        id
        currency
        resourceOptions {
          id
          name
        }
      }
    }
    """

    case query(partner, query, %{}) do
      {:ok, %{activities: activities}} ->
        {:ok, activities}
    end
  end

  @doc """
  Execute a GraphQL query against PeekPro.

  Routes through the cross-brand registry URL if `api_config.url` is present,
  otherwise calls PeekPro directly.
  """
  @spec query(Partner.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def query(partner, query, variables \\ %{})

  def query(
        %Partner{app_registry_installation_refid: "" <> install_id, api_config: %{url: "" <> base_url}},
        "" <> query,
        %{} = variables
      ) do
    # Currently there's only 1 back office api slug (version). Down the line, we
    # could have multiple (v2, widget-api, etc, etc). This is where you'd add the
    # logic to determine the correct slug.
    extendable_slug = "peek_backoffice_api-v1"

    # Peek requires the operation name to be the last part of the URL; ex
    # [base_url]/peek_backoffice_api-v1/get-bookings.
    url =
      [
        base_url,
        extendable_slug,
        Client.operation_name(query)
      ]
      |> Enum.join("/")

    PeekAppSDK.query_platform(install_id, :post, url, %{
      "query" => query,
      "variables" => variables
    })
  end

  def query(%Partner{app_registry_installation_refid: install_id}, query, variables)
      when is_binary(install_id) and is_binary(query) and is_map(variables) do
    PeekAppSDK.query_peek_pro(install_id, query, variables)
  end

  def query(%Partner{}, _query, _variables) do
    raise ArgumentError, "app_registry_installation_refid is required for :peek partners"
  end
end
