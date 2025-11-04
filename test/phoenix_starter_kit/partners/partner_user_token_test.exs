defmodule PhoenixStarterKit.Partners.PartnerUserTokenTest do
  use PhoenixStarterKit.DataCase, async: true

  alias PhoenixStarterKit.Partners.PartnerUserToken
  alias PhoenixStarterKit.Partners.PartnerUser
  import PhoenixStarterKit.PartnersFixtures

  describe "build_session_token/1" do
    test "returns a token and token struct" do
      partner_user = partner_user_fixture()
      {token, partner_user_token} = PartnerUserToken.build_session_token(partner_user)

      assert is_binary(token)
      assert partner_user_token.token == token
      assert partner_user_token.context == "session"
      assert partner_user_token.partner_user_id == partner_user.id
    end
  end

  describe "verify_session_token_query/1" do
    test "returns a query for a valid token" do
      partner_user = partner_user_fixture()
      {token, partner_user_token} = PartnerUserToken.build_session_token(partner_user)
      Repo.insert!(partner_user_token)

      assert {:ok, query} = PartnerUserToken.verify_session_token_query(token)
      assert %PartnerUser{id: id} = Repo.one(query)
      assert id == partner_user.id
    end

    test "returns a query that returns nil for an invalid token" do
      assert {:ok, query} = PartnerUserToken.verify_session_token_query("invalid")
      assert Repo.one(query) == nil
    end

    test "returns a query that returns nil for an expired token" do
      partner_user = partner_user_fixture()
      {token, partner_user_token} = PartnerUserToken.build_session_token(partner_user)

      # Insert token with old timestamp
      old_token = %{partner_user_token | inserted_at: ~U[2020-01-01 00:00:00Z]}
      Repo.insert!(old_token)

      assert {:ok, query} = PartnerUserToken.verify_session_token_query(token)
      assert Repo.one(query) == nil
    end
  end

  describe "by_token_and_context_query/2" do
    test "returns a query for a token and context" do
      partner_user = partner_user_fixture()
      {token, partner_user_token} = PartnerUserToken.build_session_token(partner_user)
      Repo.insert!(partner_user_token)

      query = PartnerUserToken.by_token_and_context_query(token, "session")
      assert %PartnerUserToken{} = Repo.one(query)
    end

    test "returns nil for a token with different context" do
      partner_user = partner_user_fixture()
      {token, partner_user_token} = PartnerUserToken.build_session_token(partner_user)
      Repo.insert!(partner_user_token)

      query = PartnerUserToken.by_token_and_context_query(token, "other_context")
      assert Repo.one(query) == nil
    end
  end

  describe "by_partner_user_and_contexts_query/2" do
    test "returns tokens for a specific partner user and all contexts" do
      partner_user = partner_user_fixture()
      other_partner_user = partner_user_fixture()

      {_token1, partner_user_token1} = PartnerUserToken.build_session_token(partner_user)
      Repo.insert!(partner_user_token1)

      # Create another token for the same partner user
      {_token2, partner_user_token2} = PartnerUserToken.build_session_token(partner_user)
      partner_user_token2 = %{partner_user_token2 | context: "other_context"}
      Repo.insert!(partner_user_token2)

      # Create a token for another partner user
      {_token3, partner_user_token3} = PartnerUserToken.build_session_token(other_partner_user)
      Repo.insert!(partner_user_token3)

      query = PartnerUserToken.by_partner_user_and_contexts_query(partner_user, :all)
      tokens = Repo.all(query)

      assert length(tokens) == 2
      assert Enum.all?(tokens, fn t -> t.partner_user_id == partner_user.id end)
    end

    test "returns tokens for a specific partner user and specific contexts" do
      partner_user = partner_user_fixture()

      {_token1, partner_user_token1} = PartnerUserToken.build_session_token(partner_user)
      partner_user_token1 = %{partner_user_token1 | context: "context1"}
      Repo.insert!(partner_user_token1)

      {_token2, partner_user_token2} = PartnerUserToken.build_session_token(partner_user)
      partner_user_token2 = %{partner_user_token2 | context: "context2"}
      Repo.insert!(partner_user_token2)

      {_token3, partner_user_token3} = PartnerUserToken.build_session_token(partner_user)
      partner_user_token3 = %{partner_user_token3 | context: "context3"}
      Repo.insert!(partner_user_token3)

      query = PartnerUserToken.by_partner_user_and_contexts_query(partner_user, ["context1", "context2"])
      tokens = Repo.all(query)

      assert length(tokens) == 2
      assert Enum.all?(tokens, fn t -> t.partner_user_id == partner_user.id end)
      assert Enum.all?(tokens, fn t -> t.context in ["context1", "context2"] end)
    end
  end
end
