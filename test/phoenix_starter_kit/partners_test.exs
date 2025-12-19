defmodule PhoenixStarterKit.PartnersTest do
  use PhoenixStarterKit.DataCase, async: true

  alias PhoenixStarterKit.Partners
  alias PhoenixStarterKit.Partners.Partner
  # PartnerUser alias not needed here
  alias PhoenixStarterKit.Partners.PartnerUserToken

  import PhoenixStarterKit.PartnersFixtures

  describe "partners" do
    test "list_partners/0 returns all partners" do
      partner = partner_fixture()
      assert Partners.list_partners() == [partner]
    end

    test "get_partner!/1 returns the partner with given id" do
      partner = partner_fixture()
      assert Partners.get_partner!(partner.id) == partner
    end

    test "get_partner_by_external_id/1 returns the partner with given external_refid" do
      partner = partner_fixture()
      assert Partners.get_partner_by_external_id(partner.external_refid) == partner
    end

    test "get_partner_by_peek_install_id/1 returns the partner with given peek_pro_installation_id" do
      partner = partner_fixture()
      assert Partners.get_partner_by_peek_install_id(partner.peek_pro_installation_id) == partner
    end

    test "create_partner/1 with valid data creates a partner" do
      valid_attrs = %{
        name: "Test Partner",
        external_refid: "external-123",
        peek_pro_installation_id: "install-123",
        is_test: false,
        timezone: "America/Los_Angeles",
        platform: :peek
      }

      assert {:ok, %Partner{} = partner} = Partners.create_partner(valid_attrs)
      assert partner.name == "Test Partner"
      assert partner.external_refid == "external-123"
      assert partner.peek_pro_installation_id == "install-123"
      assert partner.is_test == false
    end

    test "create_partner/1 with invalid data returns error changeset" do
      invalid_attrs = %{name: nil, external_refid: nil}
      assert {:error, %Ecto.Changeset{}} = Partners.create_partner(invalid_attrs)
    end

    test "create_partner/1 with invalid timezone returns error changeset" do
      invalid_attrs = %{
        name: "Test Partner",
        external_refid: "external-123",
        timezone: "invalid",
        platform: :peek
      }

      assert {:error, %Ecto.Changeset{}} = Partners.create_partner(invalid_attrs)
    end

    test "update_partner/2 with valid data updates the partner" do
      partner = partner_fixture()
      update_attrs = %{name: "Updated Partner", is_test: true}

      assert {:ok, %Partner{} = updated_partner} = Partners.update_partner(partner, update_attrs)
      assert updated_partner.name == "Updated Partner"
      assert updated_partner.is_test == true
    end

    test "update_partner/2 with invalid data returns error changeset" do
      partner = partner_fixture()
      invalid_attrs = %{name: nil, external_refid: nil}
      assert {:error, %Ecto.Changeset{}} = Partners.update_partner(partner, invalid_attrs)
      assert partner == Partners.get_partner!(partner.id)
    end

    test "update_partner/2 with peek_pro_installation updates the installation" do
      partner = partner_fixture()

      peek_pro_installation = %{
        status: :installed,
        display_version: "1.0.0",
        install_id: "install-123"
      }

      assert {:ok, %Partner{} = updated_partner} =
               Partners.update_partner(partner, %{peek_pro_installation: peek_pro_installation})

      assert updated_partner.peek_pro_installation.status == :installed
      assert updated_partner.peek_pro_installation.display_version == "1.0.0"
      assert updated_partner.peek_pro_installation.install_id == "install-123"
    end

    test "delete_partner/1 deletes the partner" do
      partner = partner_fixture()
      assert {:ok, %Partner{}} = Partners.delete_partner(partner)
      assert_raise Ecto.NoResultsError, fn -> Partners.get_partner!(partner.id) end
    end

    test "change_partner/2 returns a partner changeset" do
      partner = partner_fixture()
      assert %Ecto.Changeset{} = Partners.change_partner(partner)
    end
  end

  describe "partner users" do
    test "get_partner_user_by_email/1 returns the partner user with given email" do
      partner_user = partner_user_fixture()
      assert Partners.get_partner_user_by_email(partner_user.email) == partner_user
    end

    test "get_partner_user_by_email/1 returns nil for non-existent email" do
      assert Partners.get_partner_user_by_email("nonexistent@example.com") == nil
    end

    test "change_partner_user_registration/2 returns a partner user changeset" do
      partner_user = partner_user_fixture()
      assert %Ecto.Changeset{} = Partners.change_partner_user_registration(partner_user)
    end
  end

  describe "partner user connections" do
    test "connect_partner_user/2 connects a partner user to a partner" do
      partner = partner_fixture()
      partner_user = partner_user_fixture()

      assert {:ok, connection} = Partners.connect_partner_user(partner, partner_user)
      assert connection.partner_id == partner.id
      assert connection.partner_user_id == partner_user.id
    end

    test "connect_partner_user/2 does nothing on conflict" do
      partner = partner_fixture()
      partner_user = partner_user_fixture()

      # First connection
      assert {:ok, _} = Partners.connect_partner_user(partner, partner_user)

      # Second connection should return :ok but not create a new record
      assert {:ok, _} = Partners.connect_partner_user(partner, partner_user)
    end
  end

  describe "peek pro integration" do
    test "upsert_for_peek_pro_installation/3 creates a partner and partner user if they don't exist" do
      external_refid = "external-123"
      name = "Test Partner"
      timezone = "America/Los_Angeles"

      assert {:ok, partner} =
               Partners.upsert_for_peek_pro_installation({external_refid, :peek}, name, timezone)

      assert partner.name == name
      assert partner.external_refid == external_refid
      assert partner.timezone == timezone
      assert partner.platform == :peek

      # Should return the same partner on subsequent calls
      assert {:ok, same_partner} =
               Partners.upsert_for_peek_pro_installation({external_refid, :peek}, "New Name", timezone)

      assert same_partner.id == partner.id
    end

    test "upsert_for_peek_account_user/2 creates a partner user for a PeekPro account user" do
      partner = partner_fixture()
      peek_account_user = peek_account_user_fixture()

      partner_user = Partners.upsert_for_peek_account_user(partner, peek_account_user)
      assert partner_user.email == peek_account_user.email
      assert partner_user.name == peek_account_user.name
      assert partner_user.partner.id == partner.id

      # Should return the same partner user on subsequent calls
      same_partner_user = Partners.upsert_for_peek_account_user(partner, peek_account_user)
      assert same_partner_user.id == partner_user.id
    end
  end

  describe "session tokens" do
    setup do
      partner_user = partner_user_fixture()
      token = Partners.generate_partner_user_session_token(partner_user)
      %{partner_user: partner_user, token: token}
    end

    test "generate_partner_user_session_token/1 generates a token", %{partner_user: partner_user} do
      token = Partners.generate_partner_user_session_token(partner_user)
      assert partner_user_token = Repo.get_by(PartnerUserToken, token: token)
      assert partner_user_token.context == "session"
      assert partner_user_token.partner_user_id == partner_user.id
    end

    test "get_partner_user_by_session_token/1 returns the partner user with valid token", %{
      partner_user: partner_user,
      token: token
    } do
      assert session_partner_user = Partners.get_partner_user_by_session_token(token)
      assert session_partner_user.id == partner_user.id
    end

    test "get_partner_user_by_session_token/1 returns nil with invalid token" do
      assert Partners.get_partner_user_by_session_token("invalid") == nil
    end

    test "delete_partner_user_session_token/1 deletes the token", %{token: token} do
      assert Partners.delete_partner_user_session_token(token) == :ok
      assert Partners.get_partner_user_by_session_token(token) == nil
    end
  end
end
