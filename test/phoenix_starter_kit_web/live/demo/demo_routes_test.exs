defmodule PhoenixStarterKitWeb.Demo.DemoRoutesTest do
  # Not async: the tests change the :demo_routes application env.
  use PhoenixStarterKitWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    on_exit(fn -> Application.put_env(:phoenix_starter_kit, :demo_routes, true) end)
  end

  test "the demo pages render when demo_routes is true", %{conn: conn} do
    assert {:ok, _view, html} = live(conn, ~p"/demo/demo_records")
    assert html =~ "Listing Demo records"
  end

  test "a request without a login gets 404 when demo_routes is false", %{conn: conn} do
    Application.put_env(:phoenix_starter_kit, :demo_routes, false)

    for path <- [~p"/demo/demo_records", ~p"/demo/demo_records/new", ~p"/demo/components"] do
      assert conn |> get(path) |> response(404) == "Not Found"
    end
  end

  test "a request gets 404 when demo_routes is not set", %{conn: conn} do
    Application.delete_env(:phoenix_starter_kit, :demo_routes)

    assert conn |> get(~p"/demo/demo_records") |> response(404)
  end

  test "a socket mount redirects to / when demo_routes is false", %{conn: conn} do
    conn = get(conn, ~p"/demo/demo_records")
    assert html_response(conn, 200)

    Application.put_env(:phoenix_starter_kit, :demo_routes, false)

    assert {:error, {:redirect, %{to: "/"}}} = live(conn)
  end
end
