defmodule PhoenixStarterKit.Repo.Migrations.AddTimezoneToPartners do
  use Ecto.Migration

  def change do
    alter table(:partners) do
      add :timezone, :text, null: false
    end
  end
end
