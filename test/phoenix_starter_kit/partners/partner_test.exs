defmodule PhoenixStarterKit.Partners.PartnerTest do
  use PhoenixStarterKit.DataCase, async: true

  alias PhoenixStarterKit.Partners.Partner
  # No fixtures needed for this test

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Partner.changeset(%Partner{}, %{})

      assert %{
               name: ["can't be blank"],
               external_refid: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates with valid attributes" do
      valid_attrs = %{
        name: "Test Partner",
        external_refid: "external-123",
        app_registry_installation_refid: "install-123",
        is_test: false,
        platform: :peek
      }

      changeset = Partner.changeset(%Partner{}, valid_attrs)
      assert changeset.valid?
    end

    test "validates peek_pro_installation embed" do
      valid_attrs = %{
        name: "Test Partner",
        external_refid: "external-123",
        peek_pro_installation: %{
          status: :installed,
          display_version: "1.0.0",
          install_id: "install-123"
        }
      }

      changeset = Partner.changeset(%Partner{}, valid_attrs)
      assert changeset.valid?

      # Test with invalid peek_pro_installation
      invalid_attrs = %{
        name: "Test Partner",
        external_refid: "external-123",
        peek_pro_installation: %{
          status: :installed,
          display_version: nil,
          install_id: nil
        }
      }

      changeset = Partner.changeset(%Partner{}, invalid_attrs)
      assert %{peek_pro_installation: %{display_version: ["can't be blank"], install_id: ["can't be blank"]}} = errors_on(changeset)
    end
  end

  describe "peek_pro_installation_changeset/2" do
    test "validates required fields" do
      changeset = Partner.peek_pro_installation_changeset(%Partner.PeekProInstallation{}, %{})
      assert %{status: ["can't be blank"], display_version: ["can't be blank"], install_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates with valid attributes" do
      valid_attrs = %{
        status: :installed,
        display_version: "1.0.0",
        install_id: "install-123"
      }

      changeset = Partner.peek_pro_installation_changeset(%Partner.PeekProInstallation{}, valid_attrs)
      assert changeset.valid?
    end
  end
end
