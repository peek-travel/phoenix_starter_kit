defmodule PhoenixStarterKit.Repo.Migrations.CreatePartners do
  use Ecto.Migration

  def change do
    create table(:partners, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :external_refid, :string, null: false
      add :platform, :string, null: false
      add :peek_pro_installation_id, :string
      add :peek_pro_installation, :map
      add :is_test, :boolean, default: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:partners, [:external_refid, :platform], unique: true)
    create index(:partners, [:peek_pro_installation_id], unique: true)
  end
end
