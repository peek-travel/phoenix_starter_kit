defmodule PhoenixStarterKit.Platforms.Cng do
  @moduledoc """
  CNG platform implementation stub.

  This module exists to demonstrate the multi-platform pattern.
  Implement CNG-specific operations here when needed.
  """

  alias PhoenixStarterKit.Partners.Partner

  @spec query(Partner.t(), String.t(), map()) :: no_return()
  def query(%Partner{platform: :cng}, _query, _variables) do
    raise "CNG platform not yet implemented"
  end
end
