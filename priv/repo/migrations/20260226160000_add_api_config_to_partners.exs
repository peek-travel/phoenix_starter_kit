defmodule PhoenixStarterKit.Repo.Migrations.AddApiConfigToPartners do
  use Ecto.Migration

  def change do
    alter table(:partners) do
      add :api_config, :map
    end
  end
end
