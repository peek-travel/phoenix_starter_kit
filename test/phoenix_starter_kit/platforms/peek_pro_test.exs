defmodule PhoenixStarterKit.Platforms.PeekProTest do
  use PhoenixStarterKit.DataCase, async: true
  use Mimic

  alias PhoenixStarterKit.Platforms.PeekPro
  alias PhoenixStarterKit.Partners.Partner

  setup :verify_on_exit!

  describe "query/3" do
    test "routes through cross-brand URL when api_config.url is present" do
      partner = %Partner{
        platform: :peek,
        app_registry_installation_refid: "install-123",
        api_config: %Partner.ApiConfig{url: "https://cross-brand.example.com"}
      }

      expect(PeekAppSDK, :query_platform, fn
        "install-123",
        :post,
        "https://cross-brand.example.com/peek_backoffice_api-v1/test_query",
        %{"query" => "query TestQuery { test }", "variables" => %{"foo" => "bar"}} ->
          {:ok, %{test: "cross-brand-result"}}
      end)

      assert {:ok, %{test: "cross-brand-result"}} =
               PeekPro.query(partner, "query TestQuery { test }", %{"foo" => "bar"})
    end

    test "calls PeekPro directly when api_config.url is nil" do
      partner = %Partner{
        platform: :peek,
        app_registry_installation_refid: "install-456",
        api_config: nil
      }

      expect(PeekAppSDK, :query_peek_pro, fn "install-456", "query Direct { direct }", %{} ->
        {:ok, %{direct: "result"}}
      end)

      assert {:ok, %{direct: "result"}} = PeekPro.query(partner, "query Direct { direct }")
    end

    test "calls PeekPro directly when api_config exists but url is nil" do
      partner = %Partner{
        platform: :peek,
        app_registry_installation_refid: "install-789",
        api_config: %Partner.ApiConfig{url: nil}
      }

      expect(PeekAppSDK, :query_peek_pro, fn "install-789", "query Test { test }", %{} ->
        {:ok, %{test: "result"}}
      end)

      assert {:ok, %{test: "result"}} = PeekPro.query(partner, "query Test { test }")
    end

    test "raises when app_registry_installation_refid is missing" do
      partner = %Partner{
        platform: :peek,
        app_registry_installation_refid: nil
      }

      assert_raise ArgumentError, "app_registry_installation_refid is required for :peek partners", fn ->
        PeekPro.query(partner, "query Test { test }", %{})
      end
    end
  end

  describe "get_activities/1" do
    test "returns activities via direct PeekPro when no api_config" do
      partner = %Partner{
        platform: :peek,
        app_registry_installation_refid: "install-123",
        api_config: nil
      }

      expect(PeekAppSDK, :query_peek_pro, fn "install-123", _query, %{} ->
        {:ok, %{activities: [%{id: "activity-1", name: "Kayak Tour"}]}}
      end)

      assert {:ok, [%{name: "Kayak Tour"}]} = PeekPro.get_activities(partner)
    end

    test "returns activities via cross-brand URL when api_config.url is present" do
      partner = %Partner{
        platform: :peek,
        app_registry_installation_refid: "install-456",
        api_config: %Partner.ApiConfig{url: "https://cross-brand.example.com"}
      }

      expect(PeekAppSDK, :query_platform, fn
        "install-456",
        :post,
        "https://cross-brand.example.com/peek_backoffice_api-v1/get_activities",
        %{"query" => _query, "variables" => %{}} ->
          {:ok, %{activities: [%{id: "activity-2", name: "Snorkeling"}]}}
      end)

      assert {:ok, [%{name: "Snorkeling"}]} = PeekPro.get_activities(partner)
    end
  end
end
