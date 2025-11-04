defmodule PhoenixStarterKit.DemoTest do
  use PhoenixStarterKit.DataCase

  alias PhoenixStarterKit.Demo

  describe "demo_records" do
    alias PhoenixStarterKit.Demo.DemoRecord

    import PhoenixStarterKit.DemoFixtures

    @invalid_attrs %{
      active: nil,
      count: nil,
      name: nil,
      status: nil,
      description: nil,
      rating: nil,
      price: nil,
      tags: nil,
      published_on: nil,
      alarm_time: nil,
      naive_event_at: nil
    }

    test "list_demo_records/0 returns all demo_records" do
      demo_records = demo_record_fixture()
      assert Demo.list_demo_records() == [demo_records]
    end

    test "get_demo_record!/1 returns the demo_records with given id" do
      demo_records = demo_record_fixture()
      assert Demo.get_demo_record!(demo_records.id) == demo_records
    end

    test "create_demo_record/1 with valid data creates a demo_records" do
      valid_attrs = %{
        active: true,
        count: 42,
        name: "some name",
        status: :draft,
        description: "some description",
        rating: 120.5,
        price: "120.5",
        tags: ["option1", "option2"],
        published_on: ~D[2025-05-06],
        alarm_time: ~T[14:00:00],
        naive_event_at: ~N[2025-05-06 14:53:00]
      }

      assert {:ok, %DemoRecord{} = demo_records} = Demo.create_demo_record(valid_attrs)
      assert demo_records.active == true
      assert demo_records.count == 42
      assert demo_records.name == "some name"
      assert demo_records.status == :draft
      assert demo_records.description == "some description"
      assert demo_records.rating == 120.5
      assert demo_records.price == Decimal.new("120.5")
      assert demo_records.tags == ["option1", "option2"]
      assert demo_records.published_on == ~D[2025-05-06]
      assert demo_records.alarm_time == ~T[14:00:00]
      assert demo_records.naive_event_at == ~N[2025-05-06 14:53:00]
    end

    test "create_demo_record/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Demo.create_demo_record(@invalid_attrs)
    end

    test "update_demo_record/2 with valid data updates the demo_records" do
      demo_records = demo_record_fixture()

      update_attrs = %{
        active: false,
        count: 43,
        name: "some updated name",
        status: :published,
        description: "some updated description",
        rating: 456.7,
        price: "456.7",
        tags: ["option1"],
        published_on: ~D[2025-05-07],
        alarm_time: ~T[15:01:01],
        naive_event_at: ~N[2025-05-07 14:53:00]
      }

      assert {:ok, %DemoRecord{} = demo_records} = Demo.update_demo_record(demo_records, update_attrs)
      assert demo_records.active == false
      assert demo_records.count == 43
      assert demo_records.name == "some updated name"
      assert demo_records.status == :published
      assert demo_records.description == "some updated description"
      assert demo_records.rating == 456.7
      assert demo_records.price == Decimal.new("456.7")
      assert demo_records.tags == ["option1"]
      assert demo_records.published_on == ~D[2025-05-07]
      assert demo_records.alarm_time == ~T[15:01:01]
      assert demo_records.naive_event_at == ~N[2025-05-07 14:53:00]
    end

    test "update_demo_record/2 with invalid data returns error changeset" do
      demo_records = demo_record_fixture()
      assert {:error, %Ecto.Changeset{}} = Demo.update_demo_record(demo_records, @invalid_attrs)
      assert demo_records == Demo.get_demo_record!(demo_records.id)
    end

    test "delete_demo_record/1 deletes the demo_records" do
      demo_records = demo_record_fixture()
      assert {:ok, %DemoRecord{}} = Demo.delete_demo_record(demo_records)
      assert_raise Ecto.NoResultsError, fn -> Demo.get_demo_record!(demo_records.id) end
    end

    test "change_demo_record/1 returns a demo_records changeset" do
      demo_records = demo_record_fixture()
      assert %Ecto.Changeset{} = Demo.change_demo_record(demo_records)
    end
  end
end
