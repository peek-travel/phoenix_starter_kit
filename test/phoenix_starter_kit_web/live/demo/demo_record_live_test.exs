defmodule PhoenixStarterKitWeb.Demo.DemoRecordLiveTest do
  use PhoenixStarterKitWeb.ConnCase

  import Phoenix.LiveViewTest
  import PhoenixStarterKit.DemoFixtures

  @create_attrs %{
    active: true,
    count: 42,
    name: "some name",
    status: :draft,
    description: "some description",
    rating: 120.5,
    price: "120.5",
    tags: ["option1", "option2"],
    published_on: "2025-07-02",
    alarm_time: "14:00",
    naive_event_at: "2025-07-02T03:10:00"
  }
  @update_attrs %{
    active: false,
    count: 43,
    name: "some updated name",
    status: :published,
    description: "some updated description",
    rating: 456.7,
    price: "456.7",
    tags: ["option1"],
    published_on: "2025-07-03",
    alarm_time: "15:01",
    naive_event_at: "2025-07-03T03:10:00"
  }
  @invalid_attrs %{
    active: false,
    count: nil,
    name: nil,
    status: nil,
    description: nil,
    rating: nil,
    price: nil,
    tags: [],
    published_on: nil,
    alarm_time: nil,
    naive_event_at: nil
  }
  defp create_demo_record(_) do
    demo_record = demo_record_fixture()

    %{demo_record: demo_record}
  end

  describe "Index" do
    setup [:create_demo_record]

    test "lists all demo_records", %{conn: conn, demo_record: demo_record} do
      {:ok, index_live, _html} = live(conn, ~p"/demo/demo_records")

      assert text_for_integration_test_element(index_live, "page-title") == "Listing Demo records"
      assert text_for_integration_test_element(index_live, "demo-record-name-#{demo_record.id}") == demo_record.name
    end

    test "saves new demo_record", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/demo/demo_records")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Demo record")
               |> render_click()
               |> follow_redirect(conn, ~p"/demo/demo_records/new")

      assert text_for_integration_test_element(form_live, "page-title") == "New Demo record"

      assert form_live
             |> form("#demo_record-form", demo_record: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#demo_record-form", demo_record: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/demo/demo_records")

      assert text_for_integration_test_element(index_live, "flash-content-flash-info") == "Demo record created successfully"

      demo_record = PhoenixStarterKit.Demo.list_demo_records() |> Enum.find(&(&1.name == "some name"))
      assert text_for_integration_test_element(index_live, "demo-record-name-#{demo_record.id}") == "some name"
    end

    test "updates demo_record in listing", %{conn: conn, demo_record: demo_record} do
      {:ok, index_live, _html} = live(conn, ~p"/demo/demo_records")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#demo_records-#{demo_record.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/demo/demo_records/#{demo_record}/edit")

      assert text_for_integration_test_element(form_live, "page-title") == "Edit Demo record"

      assert form_live
             |> form("#demo_record-form", demo_record: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#demo_record-form", demo_record: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/demo/demo_records")

      assert text_for_integration_test_element(index_live, "flash-content-flash-info") == "Demo record updated successfully"
      assert text_for_integration_test_element(index_live, "demo-record-name-#{demo_record.id}") == "some updated name"
    end

    test "deletes demo_record in listing", %{conn: conn, demo_record: demo_record} do
      {:ok, index_live, _html} = live(conn, ~p"/demo/demo_records")

      assert index_live |> element("#demo_records-#{demo_record.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#demo_records-#{demo_record.id}")
    end
  end

  describe "Show" do
    setup [:create_demo_record]

    test "displays demo_record", %{conn: conn, demo_record: demo_record} do
      {:ok, show_live, _html} = live(conn, ~p"/demo/demo_records/#{demo_record}")

      assert text_for_integration_test_element(show_live, "page-title") == "Show Demo record"
      assert text_for_integration_test_element(show_live, "demo-record-name") == demo_record.name
    end

    test "updates demo_record and returns to show", %{conn: conn, demo_record: demo_record} do
      {:ok, show_live, _html} = live(conn, ~p"/demo/demo_records/#{demo_record}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/demo/demo_records/#{demo_record}/edit?return_to=show")

      assert text_for_integration_test_element(form_live, "page-title") == "Edit Demo record"

      assert form_live
             |> form("#demo_record-form", demo_record: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#demo_record-form", demo_record: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/demo/demo_records/#{demo_record}")

      assert text_for_integration_test_element(show_live, "flash-content-flash-info") == "Demo record updated successfully"
      assert text_for_integration_test_element(show_live, "demo-record-name") == "some updated name"
    end
  end
end
