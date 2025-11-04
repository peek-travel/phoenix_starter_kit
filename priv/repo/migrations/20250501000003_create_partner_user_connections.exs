defmodule PhoenixStarterKit.Repo.Migrations.CreatePartnerUserConnections do
  use Ecto.Migration

  def change do
    create table(:partner_user_connections, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :partner_id, references(:partners, on_delete: :delete_all, type: :binary_id),
        null: false

      add :partner_user_id, references(:partner_users, on_delete: :delete_all, type: :binary_id),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:partner_user_connections, [:partner_id])
    create index(:partner_user_connections, [:partner_user_id])
    create unique_index(:partner_user_connections, [:partner_id, :partner_user_id])
  end
end
