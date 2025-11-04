defmodule PhoenixStarterKit.Repo.Migrations.CreatePartnerUsersTokens do
  use Ecto.Migration

  def change do
    create table(:partner_users_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :partner_user_id, references(:partner_users, type: :binary_id, on_delete: :delete_all),
        null: false

      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false, type: :utc_datetime)
    end

    create index(:partner_users_tokens, [:partner_user_id])
    create unique_index(:partner_users_tokens, [:context, :token])
  end
end
