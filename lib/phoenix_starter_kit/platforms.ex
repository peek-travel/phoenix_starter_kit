defmodule PhoenixStarterKit.Platforms do
  @moduledoc """
  Shared entrypoint for partner platform integrations (PeekPro, ACME, CNG).

  All external GET/CREATE calls into a partner's account should go through this
  module so we can choose the correct implementation based on `partner.platform`.

  For now, only the `:peek` platform is implemented. The `:acme` and `:cng`
  platforms will raise when invoked.
  """

  alias PhoenixStarterKit.Partners.Partner
  alias PhoenixStarterKit.Platforms.Acme
  alias PhoenixStarterKit.Platforms.Cng
  alias PhoenixStarterKit.Platforms.PeekPro

  @doc """
  Execute a GraphQL query against a partner's platform.

  Delegates to the platform-specific implementation based on `partner.platform`.
  """
  @spec query(Partner.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def query(partner, query, variables \\ %{})

  def query(%Partner{platform: :peek} = partner, query, variables)
      when is_binary(query) and is_map(variables) do
    PeekPro.query(partner, query, variables)
  end

  def query(%Partner{platform: :acme} = partner, query, variables)
      when is_binary(query) and is_map(variables) do
    Acme.query(partner, query, variables)
  end

  def query(%Partner{platform: :cng} = partner, query, variables)
      when is_binary(query) and is_map(variables) do
    Cng.query(partner, query, variables)
  end
end
