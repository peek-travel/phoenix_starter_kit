defmodule PhoenixStarterKit.PartnersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `PhoenixStarterKit.Partners` context.
  """

  alias PhoenixStarterKit.Partners
  alias PhoenixStarterKit.Partners.PartnerUser

  def unique_external_refid, do: "external-#{System.unique_integer()}"
  def unique_app_registry_installation_refid, do: "install-#{System.unique_integer()}"
  def unique_partner_user_email, do: "partner_user#{System.unique_integer()}@example.com"

  def valid_partner_attributes(attrs \\ %{}) do
    attrs
    |> maybe_update_peek_pro_installation()
    |> Enum.into(%{
      name: "Partner #{System.unique_integer()}",
      external_refid: unique_external_refid(),
      app_registry_installation_refid: unique_app_registry_installation_refid(),
      is_test: false,
      timezone: "America/Los_Angeles",
      platform: :peek
    })
  end

  def partner_fixture(attrs \\ %{}) do
    {:ok, partner} =
      attrs
      |> valid_partner_attributes()
      |> Partners.create_partner()

    partner
  end

  def partner_with_installation_fixture(attrs \\ %{}) do
    partner = partner_fixture(attrs)

    peek_pro_installation = %{
      status: :installed,
      display_version: "1.0.0",
      install_id: partner.app_registry_installation_refid
    }

    {:ok, partner} =
      Partners.update_partner(partner, %{
        peek_pro_installation: peek_pro_installation
      })

    partner
  end

  def valid_partner_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_partner_user_email(),
      name: "User #{System.unique_integer()}"
    })
  end

  def partner_user_fixture(attrs \\ %{}) do
    {:ok, partner_user} =
      %PartnerUser{}
      |> PartnerUser.registration_changeset(valid_partner_user_attributes(attrs))
      |> PhoenixStarterKit.Repo.insert()

    partner_user
  end

  def partner_with_user_fixture(attrs \\ %{}) do
    partner = partner_fixture(attrs)
    partner_user = partner_user_fixture()

    {:ok, _connection} = Partners.connect_partner_user(partner, partner_user)

    %{partner: partner, partner_user: %{partner_user | partner: partner}}
  end

  def peek_account_user_fixture(attrs \\ %{}) do
    id = "user-#{System.unique_integer()}"
    email = unique_partner_user_email()
    name = "Test User #{System.unique_integer()}"

    struct = %PeekAppSDK.AccountUser{
      id: id,
      email: email,
      name: name,
      is_peek_admin: false,
      primary_role: "user"
    }

    # Return the struct with any overrides from attrs
    Map.merge(struct, attrs)
  end

  defp maybe_update_peek_pro_installation(%{peek_pro_installation: :installed} = attrs) do
    Map.replace!(attrs, :peek_pro_installation, %{
      status: :installed,
      display_version: "1.0.0",
      install_id: unique_app_registry_installation_refid()
    })
  end

  defp maybe_update_peek_pro_installation(%{peek_pro_installation: :uninstalled} = attrs) do
    Map.replace!(attrs, :peek_pro_installation, %{
      status: :uninstalled,
      display_version: "1.0.0",
      install_id: unique_app_registry_installation_refid()
    })
  end

  defp maybe_update_peek_pro_installation(attrs), do: attrs
end
