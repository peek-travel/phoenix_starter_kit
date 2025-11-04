defmodule PhoenixStarterKit.DemoFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `PhoenixStarterKit.Demo` context.
  """

  @doc """
  Generate a demo_record.
  """
  def demo_record_fixture(attrs \\ %{}) do
    {:ok, demo_record} =
      attrs
      |> Enum.into(%{
        active: true,
        alarm_time: ~T[14:00:00],
        count: 42,
        description: "some description",
        naive_event_at: ~N[2025-07-02 03:10:00],
        name: "some name #{System.unique_integer()}",
        price: "120.5",
        published_on: ~D[2025-07-02],
        rating: 120.5,
        status: :draft,
        tags: ["option1", "option2"]
      })
      |> PhoenixStarterKit.Demo.create_demo_record()

    demo_record
  end
end
