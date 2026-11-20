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

  # Tokens for the Peek Pro iframe login. The DB keeps only a SHA-256 hash of
  # each token. `sent_to` holds the ID of the partner that the token is for.
  # The login token goes in the redirect URL and works one time only.
  @embed_login_validity_in_seconds 60
  @embed_session_validity_in_seconds 86_400
  @embed_contexts ["embed_login", "embed_session"]

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

  @doc """
  Builds an iframe login token (`"embed_login"`) or session token
  (`"embed_session"`) for the partner user and the partner.

  Returns the URL-safe token for the client and the row to insert.
  """
  def build_embed_token(partner_user_id, partner_id, context) when context in @embed_contexts do
    token = :crypto.strong_rand_bytes(@rand_size)

    {Base.url_encode64(token, padding: false),
     %PartnerUserToken{token: hash(token), context: context, sent_to: partner_id, partner_user_id: partner_user_id}}
  end

  @doc """
  Returns the query for the token row when the token is in its validity time,
  or `:error` when the token is not a valid encoded token.
  """
  def verify_embed_token_query(encoded_token, context) when context in @embed_contexts do
    with {:ok, hashed} <- decode_hash(encoded_token) do
      {:ok, from(t in by_token_and_context_query(hashed, context), where: t.inserted_at > ago(^validity(context), "second"))}
    end
  end

  @doc """
  Returns the query for the embed token rows of the partner user that are
  after their validity time.
  """
  def expired_embed_tokens_query(partner_user_id) do
    expired =
      Enum.reduce(@embed_contexts, false, fn context, expired ->
        dynamic([t], ^expired or (t.context == ^context and t.inserted_at <= ago(^validity(context), "second")))
      end)

    from t in PartnerUserToken, where: t.partner_user_id == ^partner_user_id, where: ^expired
  end

  @doc """
  Returns the query for all embed token rows of the partner.
  """
  def by_partner_embed_query(partner_id) do
    from t in PartnerUserToken, where: t.sent_to == ^partner_id and t.context in @embed_contexts
  end

  @doc """
  Returns the hash of an encoded embed token, or `:error` when it is not valid.
  """
  def decode_hash(encoded_token) when is_binary(encoded_token) do
    with {:ok, token} <- Base.url_decode64(encoded_token, padding: false) do
      {:ok, hash(token)}
    end
  end

  defp hash(token), do: :crypto.hash(:sha256, token)

  defp validity("embed_login"), do: @embed_login_validity_in_seconds
  defp validity("embed_session"), do: @embed_session_validity_in_seconds
end
