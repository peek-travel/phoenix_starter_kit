defmodule PhoenixStarterKit.Repo.Migrations.RenamePeekProInstallationIdToAppRegistryInstallationRefid do
  use Ecto.Migration

  def change do
    # Drop the old index first
    drop index(:partners, [:peek_pro_installation_id],
           name: :partners_peek_pro_installation_id_index
         )

    # Rename the column
    rename table(:partners), :peek_pro_installation_id, to: :app_registry_installation_refid

    # Create the new unique index
    create unique_index(:partners, [:app_registry_installation_refid])
  end
end
