defmodule PhoenixStarterKit.Partners.PartnerUserConnection do
  @moduledoc """
  The PartnerUserConnection schema represents the many-to-many relationship
  between partners and partner users.
  """
  use PhoenixStarterKit.Schema

  schema "partner_user_connections" do
    belongs_to :partner, PhoenixStarterKit.Partners.Partner
    belongs_to :partner_user, PhoenixStarterKit.Partners.PartnerUser

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(partner_user_connection, attrs) do
    partner_user_connection
    |> cast(attrs, [:partner_id, :partner_user_id])
    |> validate_required([:partner_id, :partner_user_id])
    |> unique_constraint([:partner_id, :partner_user_id])
  end
end
