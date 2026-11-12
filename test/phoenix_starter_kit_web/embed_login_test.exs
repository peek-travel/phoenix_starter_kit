defmodule PhoenixStarterKitWeb.EmbedLoginTest do
  use PhoenixStarterKitWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest
  import PhoenixStarterKit.PartnersFixtures

  alias PhoenixStarterKit.Partners
  alias PhoenixStarterKit.Partners.PartnerUserToken
  alias PhoenixStarterKit.Repo

  setup do
    partner = partner_fixture()
    partner_user = partner_user_fixture()
    {:ok, _} = Partners.connect_partner_user(partner, partner_user)

    %{partner: partner, partner_user: partner_user, login_token: Partners.generate_embed_login_token(partner_user, partner)}
  end

  test "the login token opens /settings, and the LiveView gets the user and the locale with no cookie", %{
    partner_user: partner_user,
    login_token: login_token
  } do
    {:ok, view, html} = live(build_conn(), ~p"/settings?#{[login_token: login_token, locale: "es"]}")

    assert html =~ partner_user.email
    assert :sys.get_state(view.pid).socket.assigns.locale == "es"
  end

  test "the session cookie is SameSite=None and Secure", %{login_token: login_token} do
    conn = get(build_conn(), ~p"/settings?#{[login_token: login_token]}")

    assert [cookie] = get_resp_header(conn, "set-cookie")
    assert cookie =~ "_phoenix_starter_kit_key="
    assert cookie =~ "SameSite=None"
    assert cookie =~ "secure"
  end

  test "a second request with the same login token and no cookie shows the expired page", %{login_token: login_token} do
    path = ~p"/settings?#{[login_token: login_token]}"

    assert html_response(get(build_conn(), path), 200) =~ "welcome-message"
    assert html_response(get(build_conn(), path), 200) =~ "Session Expired"
  end

  test "a login token older than 60 seconds shows the expired page", %{login_token: login_token} do
    age_tokens("embed_login", 61)

    conn = get(build_conn(), ~p"/settings?#{[login_token: login_token]}")

    assert html_response(conn, 200) =~ "Session Expired"
  end

  test "the session cookie keeps the user logged in after the login token was used", %{login_token: login_token} do
    conn = get(build_conn(), ~p"/settings?#{[login_token: login_token]}")

    conn = conn |> recycle() |> get(~p"/settings?#{[login_token: login_token]}")

    assert html_response(conn, 200) =~ "welcome-message"
  end

  test "uninstall deletes the embed tokens of the partner and redirects the open LiveView", %{
    partner: partner,
    login_token: login_token
  } do
    {:ok, view, _html} = live(build_conn(), ~p"/settings?#{[login_token: login_token]}")
    _unused_login_token = Partners.generate_embed_login_token(partner_user_fixture(), partner)

    payload = %{
      "account" => %{"id" => partner.external_refid, "name" => partner.name, "is_test" => false},
      "display_version" => "1.0.0",
      "install_id" => partner.app_registry_installation_refid,
      "modified_by" => %{},
      "status" => "uninstalled"
    }

    build_conn()
    |> put_req_header("x-peek-auth", "Bearer #{PeekAppSDK.Token.new_for_app_installation!(partner.app_registry_installation_refid)}")
    |> post(~p"/registry/api/on-installation-status-change", payload)
    |> response(200)

    assert_redirect(view, ~p"/")
    assert Repo.aggregate(from(t in PartnerUserToken, where: t.sent_to == ^partner.id), :count) == 0
  end

  test "the LiveView ignores other messages", %{login_token: login_token} do
    {:ok, view, _html} = live(build_conn(), ~p"/settings?#{[login_token: login_token]}")

    send(view.pid, :other_message)

    assert render(view) =~ "welcome-message"
  end
end
