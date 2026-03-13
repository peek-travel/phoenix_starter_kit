defmodule PhoenixStarterKit.Partners.Partner do
  @moduledoc """
  The Partner schema represents a partner in the system.

  A partner is an entity that has installed the app and can have multiple
  partner users associated with it. The partner has information about the app
  registry installation, such as the installation ID, status, and display version.
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

    embeds_one :api_config, ApiConfig,
      on_replace: :delete,
      primary_key: false do
      @moduledoc false
      field :url, :string
    end

    embeds_one :app_registry_installation, AppRegistryInstallation,
      on_replace: :delete,
      primary_key: false do
      @moduledoc """
      Embedded schema for app registry installation details.

      Tracks the status, version, and installation ID of the app.
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
    |> cast_embed(:api_config, with: &api_config_changeset/2)
    |> cast_embed(:app_registry_installation, with: &app_registry_installation_changeset/2)
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

  @doc false
  def api_config_changeset(record, attrs) do
    record
    |> cast(attrs, [:url])
  end

  @doc """
  Changeset function for the AppRegistryInstallation embedded schema.

  Validates that status, display_version, and install_id are present.
  """
  def app_registry_installation_changeset(record, attrs) do
    record
    |> cast(attrs, [:status, :display_version, :install_id])
    |> validate_required([:status, :display_version, :install_id])
  end
end
