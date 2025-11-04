defmodule PhoenixStarterKit.Demo.DemoRecord do
  @moduledoc """
  This is a demo record that is used to demonstrate the various components
  available in the app. It is not intended to be used in production.
  """
  use PhoenixStarterKit.Schema

  schema "demo_records" do
    field :name, :string
    field :description, :string
    field :count, :integer
    field :rating, :float
    field :price, :decimal
    field :active, :boolean, default: false
    field :tags, {:array, :string}
    field :published_on, :date
    field :alarm_time, :time
    field :naive_event_at, :naive_datetime
    field :status, Ecto.Enum, values: [:draft, :published, :archived]

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(demo_record, attrs) do
    demo_record
    |> cast(attrs, [:name, :description, :count, :rating, :price, :active, :tags, :published_on, :alarm_time, :naive_event_at, :status])
    |> validate_required([
      :name,
      :description,
      :count,
      :rating,
      :price,
      :active,
      :tags,
      :published_on,
      :alarm_time,
      :naive_event_at,
      :status
    ])
    |> unique_constraint(:name)
  end
end
