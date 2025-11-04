defmodule PhoenixStarterKit.Partners.PartnerUserConnectionTest do
  use PhoenixStarterKit.DataCase, async: true

  alias PhoenixStarterKit.Partners.PartnerUserConnection
  import PhoenixStarterKit.PartnersFixtures

  describe "changeset/2" do
    test "validates required fields" do
      changeset = PartnerUserConnection.changeset(%PartnerUserConnection{}, %{})
      assert %{partner_id: ["can't be blank"], partner_user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates with valid attributes" do
      partner = partner_fixture()
      partner_user = partner_user_fixture()

      valid_attrs = %{
        partner_id: partner.id,
        partner_user_id: partner_user.id
      }

      changeset = PartnerUserConnection.changeset(%PartnerUserConnection{}, valid_attrs)
      assert changeset.valid?
    end

    test "enforces unique constraint on partner_id and partner_user_id" do
      partner = partner_fixture()
      partner_user = partner_user_fixture()

      valid_attrs = %{
        partner_id: partner.id,
        partner_user_id: partner_user.id
      }

      # First insert should succeed
      {:ok, _} =
        %PartnerUserConnection{}
        |> PartnerUserConnection.changeset(valid_attrs)
        |> Repo.insert()

      # Second insert should fail with unique constraint error
      {:error, changeset} =
        %PartnerUserConnection{}
        |> PartnerUserConnection.changeset(valid_attrs)
        |> Repo.insert()

      assert %{partner_id: ["has already been taken"]} = errors_on(changeset)
    end
  end
end
