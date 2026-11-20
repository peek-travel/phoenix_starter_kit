defmodule PhoenixStarterKitWeb.LogFilterTest do
  # Not async: the test changes the global Logger level.
  use PhoenixStarterKitWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import PhoenixStarterKit.PartnersFixtures

  setup do
    level = Logger.level()
    on_exit(fn -> Logger.configure(level: level) end)
  end

  # Logs at the debug level only inside the function, so the test output stays short.
  defp with_debug_log(fun) do
    level = Logger.level()
    Logger.configure(level: :debug)

    try do
      with_log(fun)
    after
      Logger.configure(level: level)
    end
  end

  test "the request logs have no token values" do
    partner = partner_fixture()
    account_user = peek_account_user_fixture()
    peek_auth = PeekAppSDK.Token.new_for_app_installation!(partner.app_registry_installation_refid, account_user)

    {login_token, log} =
      with_debug_log(fn ->
        conn = post(build_conn(), ~p"/peek-pro/settings", %{"peek-auth" => peek_auth})
        %{"login_token" => login_token} = conn |> redirected_to() |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

        {:ok, view, _html} = live(build_conn(), ~p"/settings?#{[login_token: login_token]}")
        render(view)
        login_token
      end)

    assert log =~ "POST /peek-pro/settings"
    assert log =~ "GET /settings"
    assert log =~ "MOUNT PhoenixStarterKitWeb.SettingsLive"

    for value <- [peek_auth, login_token] do
      refute log =~ value
    end
  end

  test "the x-peek-auth header value is not logged" do
    partner = partner_fixture()
    token = PeekAppSDK.Token.new_for_app_installation!(partner.app_registry_installation_refid)

    {_conn, log} =
      with_debug_log(fn ->
        build_conn()
        |> put_req_header("x-peek-auth", "Bearer #{token}")
        |> post(~p"/peek-pro/api/on-booking-change", %{})
      end)

    assert log =~ "POST /peek-pro/api/on-booking-change"
    refute log =~ token
  end
end
