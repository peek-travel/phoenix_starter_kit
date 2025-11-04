defmodule PhoenixStarterKit.Partners.PartnerUserTest do
  use PhoenixStarterKit.DataCase, async: true

  alias PhoenixStarterKit.Partners.PartnerUser
  import PhoenixStarterKit.PartnersFixtures

  describe "registration_changeset/2" do
    test "validates email" do
      # Test with valid attributes
      valid_attrs = %{
        email: "test@example.com",
        name: "Test User"
      }

      changeset = PartnerUser.registration_changeset(%PartnerUser{}, valid_attrs)
      assert changeset.valid?

      # Test with invalid email
      invalid_email_attrs = %{email: "invalid", name: "Test User"}
      changeset = PartnerUser.registration_changeset(%PartnerUser{}, invalid_email_attrs)
      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)

      # Test with email too long
      long_email_attrs = %{email: String.duplicate("a", 150) <> "@example.com", name: "Test User"}
      changeset = PartnerUser.registration_changeset(%PartnerUser{}, long_email_attrs)
      assert %{email: ["should be at most 160 character(s)"]} = errors_on(changeset)
    end

    test "requires email" do
      changeset = PartnerUser.registration_changeset(%PartnerUser{}, %{name: "Test User"})
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email uniqueness" do
      %{email: email} = partner_user_fixture()

      {:error, changeset} =
        %PartnerUser{}
        |> PartnerUser.registration_changeset(%{email: email, name: "Another User"})
        |> Repo.insert()

      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end

    test "does not validate email uniqueness when validate_email is false" do
      changeset =
        PartnerUser.registration_changeset(
          %PartnerUser{},
          %{email: "test@example.com", name: "Test User"},
          validate_email: false
        )

      assert changeset.valid?
    end
  end
end
