defmodule PhoenixStarterKit.Repo.Migrations.RenamePeekProInstallationToAppRegistryInstallation do
  use Ecto.Migration

  def change do
    rename table(:partners), :peek_pro_installation, to: :app_registry_installation
  end
end
