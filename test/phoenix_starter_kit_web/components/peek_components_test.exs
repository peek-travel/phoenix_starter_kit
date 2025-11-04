defmodule PhoenixStarterKitWeb.Components.PeekComponentsTest do
  use PhoenixStarterKitWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PhoenixStarterKitWeb.Components.PeekComponents

  describe "tabs component" do
    test "renders tabs with info icon when info_icon is true on a tab" do
      html =
        render_component(&PeekComponents.tabs/1, %{
          current_path: "/demo/components",
          tabs: [
            %{name: "Overview", path: "/demo/components", info_icon: true},
            %{name: "Forms", path: "/demo/demo_records"}
          ]
        })

      assert html =~ "Overview"
      assert html =~ "hero-information-circle"
    end
  end
end
