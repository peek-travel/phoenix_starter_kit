defmodule PhoenixStarterKit.Repo.Migrations.RemoveUniqueConstraintOnPartnerExternalRefidAndPlatform do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    drop_if_exists index(:partners, [:external_refid, :platform], concurrently: true)
  end
end
