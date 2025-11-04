defmodule PhoenixStarterKitWeb.Demo.DemoComponentsTest do
  use PhoenixStarterKitWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "show" do
    test "renders the page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/demo/components")
      assert html =~ "Core Components Demo"
    end
  end

  describe "handle_event - flash messages" do
    test "show_flash_info displays flash info message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/demo/components")

      html = view |> element("[phx-click=\"show_flash_info\"]") |> render_click()

      assert html =~ "This is a flash info message with a very long text"
    end

    test "show_flash_error displays flash error message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/demo/components")

      html = view |> element("[phx-click=\"show_flash_error\"]") |> render_click()

      assert html =~ "This is a flash error message!"
    end
  end
end
