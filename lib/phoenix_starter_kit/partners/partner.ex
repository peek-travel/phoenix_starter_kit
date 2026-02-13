defmodule PhoenixStarterKit.Partners.Partner do
  @moduledoc """
  The Partner schema represents a partner in the system.

  A partner is an entity that has installed the PeekPro app and can have multiple
  partner users associated with it. The partner has information about the PeekPro
  installation, such as the installation ID, status, and display version.
  """
  use PhoenixStarterKit.Schema

  schema "partners" do
    many_to_many :partner_users, PhoenixStarterKit.Partners.PartnerUser, join_through: PhoenixStarterKit.Partners.PartnerUserConnection

    field :name, :string
    field :external_refid, :string
    field :app_registry_installation_refid, :string
    field :is_test, :boolean, default: false
    field :timezone, :string
    field :platform, Ecto.Enum, values: [:peek, :acme, :cng], default: :peek

    embeds_one :peek_pro_installation, PeekProInstallation,
      on_replace: :delete,
      primary_key: false do
      @moduledoc """
      Embedded schema for PeekPro installation details.

      Tracks the status, version, and installation ID of the PeekPro app.
      """
      field :status, Ecto.Enum,
        values: [
          :installed,
          :uninstalled,
          :update_installed
        ]

      field :display_version, :string
      field :install_id, :string
    end

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(partner, attrs) do
    partner
    |> cast(attrs, [:name, :external_refid, :app_registry_installation_refid, :is_test, :timezone, :platform])
    |> cast_embed(:peek_pro_installation, with: &peek_pro_installation_changeset/2)
    |> validate_required([:name, :external_refid, :platform])
    |> validate_timezone()
  end

  defp validate_timezone(changeset) do
    validate_change(changeset, :timezone, fn :timezone, timezone ->
      case DateTime.now(timezone) do
        {:ok, _} -> []
        {:error, _} -> [timezone: "is not a valid timezone"]
      end
    end)
  end

  @doc """
  Changeset function for the PeekProInstallation embedded schema.

  Validates that status, display_version, and install_id are present.
  """
  def peek_pro_installation_changeset(record, attrs) do
    record
    |> cast(attrs, [:status, :display_version, :install_id])
    |> validate_required([:status, :display_version, :install_id])
  end
end
