defmodule PhoenixStarterKit.Repo.Migrations.MakeTimezoneNullable do
  use Ecto.Migration

  def change do
    # New registry doesn't send timezone (yet), so we need to allow NULL.
    alter table(:partners) do
      modify :timezone, :text, null: true, from: {:text, null: false}
    end
  end
end
