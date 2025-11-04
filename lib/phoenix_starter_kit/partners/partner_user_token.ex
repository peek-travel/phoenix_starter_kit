defmodule PhoenixStarterKit.Partners.PartnerUserToken do
  @moduledoc """
  This module handles token generation and verification for partner users.

  It provides functions for generating and verifying tokens for various contexts,
  such as session tokens, reset password tokens, and email confirmation tokens.
  It also handles token expiration and cleanup.
  """
  use PhoenixStarterKit.Schema
  import Ecto.Query
  alias PhoenixStarterKit.Partners.PartnerUserToken

  @rand_size 32
  @session_validity_in_days 60

  schema "partner_users_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    belongs_to :partner_user, PhoenixStarterKit.Partners.PartnerUser

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Generates a token that will be stored in a signed place,
  such as session or cookie. As they are signed, those
  tokens do not need to be hashed.

  The reason why we store session tokens in the database, even
  though Phoenix already provides a session cookie, is because
  Phoenix' default session cookies are not persisted, they are
  simply signed and potentially encrypted. This means they are
  valid indefinitely, unless you change the signing/encryption
  salt.

  Therefore, storing them allows individual partner_user
  sessions to be expired. The token system can also be extended
  to store additional data, such as the device used for logging in.
  You could then use this information to display all valid sessions
  and devices in the UI and allow users to explicitly expire any
  session they deem invalid.
  """
  def build_session_token(partner_user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, %PartnerUserToken{token: token, context: "session", partner_user_id: partner_user.id}}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the partner_user found by the token, if any.

  The token is valid if it matches the value in the database and it has
  not expired (after @session_validity_in_days).
  """
  def verify_session_token_query(token) do
    query =
      from token in by_token_and_context_query(token, "session"),
        join: partner_user in assoc(token, :partner_user),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: partner_user

    {:ok, query}
  end

  @doc """
  Returns the token struct for the given token value and context.
  """
  def by_token_and_context_query(token, context) do
    from PartnerUserToken, where: [token: ^token, context: ^context]
  end

  @doc """
  Gets all tokens for the given partner_user for the given contexts.
  """
  def by_partner_user_and_contexts_query(partner_user, :all) do
    from t in PartnerUserToken, where: t.partner_user_id == ^partner_user.id
  end

  def by_partner_user_and_contexts_query(partner_user, [_ | _] = contexts) do
    from t in PartnerUserToken,
      where: t.partner_user_id == ^partner_user.id and t.context in ^contexts
  end
end
