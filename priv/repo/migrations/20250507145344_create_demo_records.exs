defmodule PhoenixStarterKit.Repo.Migrations.CreateDemoRecords do
  use Ecto.Migration

  def change do
    create table(:demo_records, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :description, :text
      add :count, :integer
      add :rating, :float
      add :price, :decimal
      add :active, :boolean, default: false, null: false
      add :tags, {:array, :string}
      add :published_on, :date
      add :alarm_time, :time
      add :naive_event_at, :naive_datetime
      add :status, :string

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:demo_records, [:name])
  end
end
