defmodule PhoenixStarterKit.Platforms.Acme do
  @moduledoc """
  ACME platform implementation stub.

  This module exists to demonstrate the multi-platform pattern.
  Implement ACME-specific operations here when needed.
  """

  alias PhoenixStarterKit.Partners.Partner

  @spec query(Partner.t(), String.t(), map()) :: no_return()
  def query(%Partner{platform: :acme}, _query, _variables) do
    raise "ACME platform not yet implemented"
  end
end
