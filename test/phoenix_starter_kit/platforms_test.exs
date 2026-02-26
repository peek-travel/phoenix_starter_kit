defmodule PhoenixStarterKit.PlatformsTest do
  use PhoenixStarterKit.DataCase, async: true
  use Mimic

  alias PhoenixStarterKit.Platforms
  alias PhoenixStarterKit.Partners.Partner

  setup :verify_on_exit!

  describe "query/3" do
    test "dispatches to PeekPro for :peek platform partners" do
      partner = %Partner{
        platform: :peek,
        app_registry_installation_refid: "install-123"
      }

      expect(PeekAppSDK, :query_peek_pro, fn "install-123", "query Test { test }", %{} ->
        {:ok, %{test: "result"}}
      end)

      assert {:ok, %{test: "result"}} = Platforms.query(partner, "query Test { test }")
    end

    test "dispatches to Acme for :acme platform partners" do
      partner = %Partner{platform: :acme}

      assert_raise RuntimeError, "ACME platform not yet implemented", fn ->
        Platforms.query(partner, "query Test { test }", %{})
      end
    end

    test "dispatches to Cng for :cng platform partners" do
      partner = %Partner{platform: :cng}

      assert_raise RuntimeError, "CNG platform not yet implemented", fn ->
        Platforms.query(partner, "query Test { test }", %{})
      end
    end
  end
end
