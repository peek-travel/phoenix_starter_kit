defmodule PhoenixStarterKitWebTest do
  use ExUnit.Case, async: true

  describe "static_paths/0" do
    test "returns expected static paths" do
      assert "assets" in PhoenixStarterKitWeb.static_paths()
      assert "favicon.ico" in PhoenixStarterKitWeb.static_paths()
    end
  end

  describe "__using__ macro helpers" do
    test "router/0 returns quoted expression" do
      assert is_tuple(PhoenixStarterKitWeb.router())
    end

    test "channel/0 returns quoted expression" do
      assert is_tuple(PhoenixStarterKitWeb.channel())
    end

    test "controller/0 returns quoted expression" do
      assert is_tuple(PhoenixStarterKitWeb.controller())
    end

    test "live_view/0 returns quoted expression" do
      assert is_tuple(PhoenixStarterKitWeb.live_view())
    end

    test "live_component/0 returns quoted expression" do
      assert is_tuple(PhoenixStarterKitWeb.live_component())
    end

    test "html/0 returns quoted expression" do
      assert is_tuple(PhoenixStarterKitWeb.html())
    end

    test "verified_routes/0 returns quoted expression" do
      assert is_tuple(PhoenixStarterKitWeb.verified_routes())
    end
  end
end
