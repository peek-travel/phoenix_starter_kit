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
      {:ok, _index_live, html} = live(conn, ~p"/demo/demo_records")

      assert html =~ "Listing Demo records"
      assert html =~ demo_record.name
    end

    test "saves new demo_record", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/demo/demo_records")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Demo record")
               |> render_click()
               |> follow_redirect(conn, ~p"/demo/demo_records/new")

      assert render(form_live) =~ "New Demo record"

      assert form_live
             |> form("#demo_record-form", demo_record: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#demo_record-form", demo_record: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/demo/demo_records")

      html = render(index_live)
      assert html =~ "Demo record created successfully"
      assert html =~ "some name"
    end

    test "updates demo_record in listing", %{conn: conn, demo_record: demo_record} do
      {:ok, index_live, _html} = live(conn, ~p"/demo/demo_records")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#demo_records-#{demo_record.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/demo/demo_records/#{demo_record}/edit")

      assert render(form_live) =~ "Edit Demo record"

      assert form_live
             |> form("#demo_record-form", demo_record: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#demo_record-form", demo_record: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/demo/demo_records")

      html = render(index_live)
      assert html =~ "Demo record updated successfully"
      assert html =~ "some updated name"
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
      {:ok, _show_live, html} = live(conn, ~p"/demo/demo_records/#{demo_record}")

      assert html =~ "Show Demo record"
      assert html =~ demo_record.name
    end

    test "updates demo_record and returns to show", %{conn: conn, demo_record: demo_record} do
      {:ok, show_live, _html} = live(conn, ~p"/demo/demo_records/#{demo_record}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/demo/demo_records/#{demo_record}/edit?return_to=show")

      assert render(form_live) =~ "Edit Demo record"

      assert form_live
             |> form("#demo_record-form", demo_record: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#demo_record-form", demo_record: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/demo/demo_records/#{demo_record}")

      html = render(show_live)
      assert html =~ "Demo record updated successfully"
      assert html =~ "some updated name"
    end
  end
end
