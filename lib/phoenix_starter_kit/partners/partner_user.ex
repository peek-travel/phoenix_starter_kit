defmodule PhoenixStarterKit.Partners.PartnerUser do
  @moduledoc """
  The PartnerUser schema represents a user who can log in to the system on
  behalf of a partner.

  A partner user can be associated with multiple partners through the
  PartnerUserConnection join table. The partner user has a virtual field for the
  current partner they are viewing the app on behalf of.
  """
  use PhoenixStarterKit.Schema

  schema "partner_users" do
    many_to_many :partners, PhoenixStarterKit.Partners.Partner, join_through: PhoenixStarterKit.Partners.PartnerUserConnection

    field :email, :string
    field :confirmed_at, :utc_datetime
    field :name, :string

    # Partner users is technically a many-to-many but we want it to feel like as
    # a belongs to partner. This will be set by the auth system.
    field :partner, :map, virtual: true

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  A partner_user changeset for registration.

  It is important to validate the length of the email.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour.

  ## Options

    * `:validate_email` - Validates the uniqueness of the email, in case
      you don't want to validate the uniqueness of the email (like when
      using this changeset for validations on a LiveView form before
      submitting the form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(partner_user, attrs, opts \\ []) do
    partner_user
    |> cast(attrs, [:email, :name])
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, PhoenixStarterKit.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end
end
