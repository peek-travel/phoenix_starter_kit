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
  Gets a single partner by peek_pro_installation_id.

  Returns nil if the Partner does not exist.

  ## Examples

      iex> get_partner_by_peek_install_id("install-123")
      %Partner{}

      iex> get_partner_by_peek_install_id("non-existent")
      nil

  """
  def get_partner_by_peek_install_id(peek_install_id) do
    Repo.get_by(Partner, peek_pro_installation_id: peek_install_id)
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
  Creates or updates a partner for a PeekPro installation.

  If a partner with the given external_refid exists, returns it.
  Otherwise, creates a new partner with the given external_refid, name, and platform.

  ## Examples

      iex> upsert_for_peek_pro_installation({"external-123", :peek}, "Test Partner", "America/Los_Angeles")
      {:ok, %Partner{}}

  """
  def upsert_for_peek_pro_installation({external_refid, platform}, name, timezone) do
    case get_partner_by_external_id(external_refid) do
      nil ->
        create_partner(%{
          name: name,
          external_refid: external_refid,
          timezone: timezone,
          platform: platform
        })

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
