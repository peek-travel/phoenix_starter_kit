defmodule PhoenixStarterKit.Partners do
  @moduledoc """
  The Partners context.
  """

  import Ecto.Query, warn: false
  alias PhoenixStarterKit.Repo

  alias PhoenixStarterKit.Partners.Partner
  alias PhoenixStarterKit.Partners.PartnerUser
  alias PhoenixStarterKit.Partners.PartnerUserToken
  alias PhoenixStarterKit.Partners.PartnerUserConnection

  @doc """
  Returns the list of partners.

  ## Examples

      iex> list_partners()
      [%Partner{}, ...]

  """
  def list_partners do
    Repo.all(Partner)
  end

  @doc """
  Gets a single partner.

  Raises `Ecto.NoResultsError` if the Partner does not exist.

  ## Examples

      iex> get_partner!(123)
      %Partner{}

      iex> get_partner!(456)
      ** (Ecto.NoResultsError)

  """
  def get_partner!(id), do: Repo.get!(Partner, id)

  @doc """
  Gets a single partner by external_refid.

  Returns nil if the Partner does not exist.

  ## Examples

      iex> get_partner_by_external_id("external-123")
      %Partner{}

      iex> get_partner_by_external_id("non-existent")
      nil

  """
  def get_partner_by_external_id(external_refid) do
    Repo.get_by(Partner, external_refid: external_refid)
  end

  @doc """
  Gets a single partner by app_registry_installation_refid.

  Returns nil if the Partner does not exist.

  ## Examples

      iex> get_partner_by_app_registry_install_refid("install-123")
      %Partner{}

      iex> get_partner_by_app_registry_install_refid("non-existent")
      nil

  """
  def get_partner_by_app_registry_install_refid(install_refid) do
    Repo.get_by(Partner, app_registry_installation_refid: install_refid)
  end

  @doc """
  Creates a partner.

  ## Examples

      iex> create_partner(%{field: value})
      {:ok, %Partner{}}

      iex> create_partner(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_partner(attrs \\ %{}) do
    %Partner{}
    |> Partner.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a partner.

  ## Examples

      iex> update_partner(partner, %{field: new_value})
      {:ok, %Partner{}}

      iex> update_partner(partner, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_partner(%Partner{} = partner, attrs) do
    partner
    |> Partner.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a partner.

  ## Examples

      iex> delete_partner(partner)
      {:ok, %Partner{}}

      iex> delete_partner(partner)
      {:error, %Ecto.Changeset{}}

  """
  def delete_partner(%Partner{} = partner) do
    Repo.delete(partner)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking partner changes.

  ## Examples

      iex> change_partner(partner)
      %Ecto.Changeset{data: %Partner{}}

  """
  def change_partner(%Partner{} = partner, attrs \\ %{}) do
    Partner.changeset(partner, attrs)
  end

  @doc """
  Creates or updates a partner for an App Registry installation.

  If a partner with the given install_id exists, returns it.
  Otherwise, creates a new partner with the given attributes.

  ## Examples

      iex> upsert_for_app_registry_installation("install-123", %{external_refid: "ext-123", platform: :peek, name: "Test", timezone: "America/Los_Angeles"})
      {:ok, %Partner{}}

  """
  def upsert_for_app_registry_installation(install_id, attrs) do
    case get_partner_by_app_registry_install_refid(install_id) do
      nil ->
        attrs
        |> Map.put(:app_registry_installation_refid, install_id)
        |> create_partner()

      partner ->
        {:ok, partner}
    end
  end

  @doc """
  Creates a partner user for a PeekPro account user.

  Returns the partner_user with the current partner set.
  """
  def upsert_for_peek_account_user(current_partner, %PeekAppSDK.AccountUser{} = peek_account_user) do
    partner_user =
      case get_partner_user_by_email(peek_account_user.email) do
        nil ->
          partner_user =
            %PartnerUser{}
            |> PartnerUser.registration_changeset(%{
              email: peek_account_user.email,
              name: peek_account_user.name
            })
            |> Repo.insert!(
              on_conflict: {:replace, [:updated_at, :name]},
              conflict_target: :email,
              returning: true
            )

          partner_user

        partner_user ->
          partner_user
      end

    connect_partner_user(current_partner, partner_user)
    %{partner_user | partner: current_partner}
  end

  @doc """
  Gets a partner user by email.

  Returns nil if the PartnerUser does not exist.
  """
  def get_partner_user_by_email(email) when is_binary(email) do
    Repo.get_by(PartnerUser, email: email)
  end

  @doc """
  Connects a partner user to a partner.

  Creates a PartnerUserConnection if one doesn't already exist.
  """
  def connect_partner_user(%Partner{} = partner, %PartnerUser{} = partner_user) do
    %PartnerUserConnection{}
    |> PartnerUserConnection.changeset(%{
      partner_id: partner.id,
      partner_user_id: partner_user.id
    })
    |> Repo.insert(on_conflict: :nothing)
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_partner_user_session_token(partner_user) do
    {token, partner_user_token} = PartnerUserToken.build_session_token(partner_user)
    Repo.insert!(partner_user_token)
    token
  end

  @doc """
  Gets the partner_user with the given signed token.

  If a partner_id is provided, it will set the current partner for the partner_user.
  """
  def get_partner_user_by_session_token(token, maybe_partner_id \\ nil) do
    {:ok, query} = PartnerUserToken.verify_session_token_query(token)
    partner_user = Repo.one(query)
    set_current_partner(partner_user, maybe_partner_id)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_partner_user_session_token(token) do
    Repo.delete_all(PartnerUserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  @doc """
  Creates a one-time login token for the Peek Pro iframe login of the partner
  user to the partner. It is valid for 60 seconds.

  It also deletes the expired iframe login and session tokens.
  """
  def generate_embed_login_token(%PartnerUser{} = partner_user, %Partner{} = partner) do
    Repo.delete_all(PartnerUserToken.expired_embed_tokens_query())
    {token, row} = PartnerUserToken.build_embed_token(partner_user.id, partner.id, "embed_login")
    Repo.insert!(row)
    token
  end

  @doc """
  Exchanges a login token from `generate_embed_login_token/2` for a session
  token that is valid for 24 hours. The login token works one time only.

  Returns `{:ok, session_token}`, or `:error` when the login token is not valid.
  """
  def exchange_embed_login_token(login_token) when is_binary(login_token) do
    with {:ok, query} <- PartnerUserToken.verify_embed_token_query(login_token, "embed_login"),
         {1, [row]} <- Repo.delete_all(select(query, [t], t)) do
      {session_token, session_row} = PartnerUserToken.build_embed_token(row.partner_user_id, row.sent_to, "embed_session")
      Repo.insert!(session_row)
      {:ok, session_token}
    else
      _ -> :error
    end
  end

  @doc """
  Gets the partner_user, with its current partner set, for a valid iframe
  session token. Returns `nil` otherwise.
  """
  def get_partner_user_by_embed_session_token(session_token) when is_binary(session_token) do
    with {:ok, query} <- PartnerUserToken.verify_embed_token_query(session_token, "embed_session"),
         %PartnerUserToken{} = row <- query |> preload(:partner_user) |> Repo.one() do
      set_current_partner(row.partner_user, row.sent_to)
    else
      _ -> nil
    end
  end

  @doc """
  Deletes the iframe session token and disconnects the LiveViews that use it.
  """
  def delete_embed_session_token(session_token) when is_binary(session_token) do
    with {:ok, hashed} <- PartnerUserToken.decode_hash(session_token) do
      Repo.delete_all(PartnerUserToken.by_token_and_context_query(hashed, "embed_session"))
      broadcast_embed_session_revoked(hashed)
    end

    :ok
  end

  @doc """
  Deletes all iframe login and session tokens for the partner and disconnects
  the LiveViews that use them. The app calls this when the partner uninstalls it.
  """
  def delete_embed_tokens_for_partner(%Partner{} = partner) do
    {_count, hashes} = Repo.delete_all(select(PartnerUserToken.by_partner_embed_query(partner.id), [t], t.token))
    Enum.each(hashes, &broadcast_embed_session_revoked/1)
    :ok
  end

  @doc """
  Returns the PubSub topic that gets `:embed_session_revoked` when the iframe
  session token is deleted, or `nil` for a token that is not valid.
  """
  def embed_session_topic(session_token) when is_binary(session_token) do
    case PartnerUserToken.decode_hash(session_token) do
      {:ok, hashed} -> embed_session_topic_for_hash(hashed)
      :error -> nil
    end
  end

  defp embed_session_topic_for_hash(hashed), do: "embed_session:" <> Base.url_encode64(hashed, padding: false)

  defp broadcast_embed_session_revoked(hashed) do
    Phoenix.PubSub.broadcast(PhoenixStarterKit.PubSub, embed_session_topic_for_hash(hashed), :embed_session_revoked)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking partner_user changes.

  ## Examples

      iex> change_partner_user_registration(partner_user)
      %Ecto.Changeset{data: %PartnerUser{}}

  """
  def change_partner_user_registration(%PartnerUser{} = partner_user, attrs \\ %{}) do
    PartnerUser.registration_changeset(partner_user, attrs)
  end

  @doc """
  Sets the current partner for a partner user; a given login to PeekPro might
  have access to many Partners. The partner that is currently being viewed is
  considered a "connected partner" for the app.

  This is called when iFramed into Peek Pro and set in the session so as the
  user navigates around the app, the current partner stays consistent.
  """
  def set_current_partner(nil, _), do: nil

  def set_current_partner(partner_user, nil) do
    partner_user = Repo.preload(partner_user, :partners)

    if Enum.empty?(partner_user.partners) do
      partner_user
    else
      partner = partner_user.partners |> Enum.sort_by(& &1.inserted_at, :desc) |> List.first()
      set_current_partner(partner_user, partner)
    end
  end

  def set_current_partner(partner_user, partner_id) when is_binary(partner_id) do
    partner_user = Repo.preload(partner_user, :partners)

    partner = Enum.find(partner_user.partners, &(&1.id == partner_id))

    set_current_partner(partner_user, partner)
  end

  def set_current_partner(partner_user, %Partner{} = partner) do
    %{partner_user | partner: partner}
  end
end
