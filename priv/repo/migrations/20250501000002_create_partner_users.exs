defmodule PhoenixStarterKit.Repo.Migrations.CreatePartnerUsers do
  use Ecto.Migration

  def change do
    create table(:partner_users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :confirmed_at, :utc_datetime
      add :name, :string

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:partner_users, [:email])
  end
end
