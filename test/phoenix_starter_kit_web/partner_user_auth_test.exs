defmodule PhoenixStarterKitWeb.PartnerUserAuthTest do
  use PhoenixStarterKitWeb.ConnCase, async: true

  alias Phoenix.LiveView
  alias PhoenixStarterKit.Partners
  alias PhoenixStarterKitWeb.PartnerUserAuth

  import PhoenixStarterKit.PartnersFixtures

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, PhoenixStarterKitWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{partner_user: partner_user_fixture(), conn: conn}
  end

  describe "log_in_partner_user/3" do
    test "stores the partner_user token in the session", %{conn: conn, partner_user: partner_user} do
      conn = PartnerUserAuth.log_in_partner_user(conn, partner_user)
      assert token = get_session(conn, :partner_user_token)

      assert get_session(conn, :live_socket_id) ==
               "partner_users_sessions:#{Base.url_encode64(token)}"

      assert redirected_to(conn) == ~p"/settings"
      assert Partners.get_partner_user_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{
      conn: conn,
      partner_user: partner_user
    } do
      conn =
        conn
        |> put_session(:to_be_removed, "value")
        |> PartnerUserAuth.log_in_partner_user(partner_user)

      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, partner_user: partner_user} do
      conn =
        conn
        |> put_session(:partner_user_return_to, "/hello")
        |> PartnerUserAuth.log_in_partner_user(partner_user)

      assert redirected_to(conn) == "/hello"
    end
  end

  describe "logout_partner_user/1" do
    test "erases session and cookies", %{conn: conn, partner_user: partner_user} do
      partner_user_token = Partners.generate_partner_user_session_token(partner_user)

      conn =
        conn
        |> put_session(:partner_user_token, partner_user_token)
        |> fetch_cookies()
        |> PartnerUserAuth.log_out_partner_user()

      refute get_session(conn, :partner_user_token)
      assert redirected_to(conn) == ~p"/"
      refute Partners.get_partner_user_by_session_token(partner_user_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "partner_users_sessions:abcdef-token"
      PhoenixStarterKitWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> PartnerUserAuth.log_out_partner_user()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "deletes the embed session token and notifies its LiveViews", %{conn: conn, partner_user: partner_user} do
      partner = partner_fixture()
      token = embed_session_token_fixture(partner_user, partner)
      Phoenix.PubSub.subscribe(PhoenixStarterKit.PubSub, Partners.embed_session_topic(token))

      conn
      |> put_session(:embed_session_token, token)
      |> PartnerUserAuth.log_out_partner_user()

      refute Partners.get_partner_user_by_embed_session_token(token)
      assert_receive :embed_session_revoked
    end

    test "works even if partner_user is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> PartnerUserAuth.log_out_partner_user()
      refute get_session(conn, :partner_user_token)
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_partner_user_from_login_token/2" do
    setup %{partner_user: partner_user} do
      partner = partner_fixture()
      {:ok, _} = Partners.connect_partner_user(partner, partner_user)
      %{partner: partner, login_token: Partners.generate_embed_login_token(partner_user, partner)}
    end

    test "puts an embed session token and the locale in the session", %{
      conn: conn,
      partner_user: partner_user,
      partner: partner,
      login_token: login_token
    } do
      conn =
        conn
        |> Map.put(:params, %{"login_token" => login_token, "locale" => "es"})
        |> PartnerUserAuth.fetch_partner_user_from_login_token([])

      embed_session_token = get_session(conn, :embed_session_token)
      assert get_session(conn, :embed_locale) == "es"
      assert embed_session_token != login_token

      embed_partner_user = Partners.get_partner_user_by_embed_session_token(embed_session_token)
      assert embed_partner_user.id == partner_user.id
      assert embed_partner_user.partner.id == partner.id
    end

    test "renews the session and removes the old session keys", %{conn: conn, login_token: login_token} do
      conn =
        conn
        |> put_session(:partner_user_token, "old-token")
        |> put_session("current_partner_id", "old-partner-id")
        |> Map.put(:params, %{"login_token" => login_token})
        |> PartnerUserAuth.fetch_partner_user_from_login_token([])

      assert get_session(conn, :embed_session_token)
      refute get_session(conn, :partner_user_token)
      refute get_session(conn, "current_partner_id")
      assert conn.private.plug_session_info == :renew
    end

    test "puts a nil locale in the session for a blank locale param", %{conn: conn, login_token: login_token} do
      conn =
        conn
        |> Map.put(:params, %{"login_token" => login_token, "locale" => ""})
        |> PartnerUserAuth.fetch_partner_user_from_login_token([])

      assert get_session(conn, :embed_session_token)
      assert get_session(conn, :embed_locale) == nil
    end

    test "accepts a login token one time only", %{conn: conn, login_token: login_token} do
      conn
      |> Map.put(:params, %{"login_token" => login_token})
      |> PartnerUserAuth.fetch_partner_user_from_login_token([])

      conn =
        conn
        |> Map.put(:params, %{"login_token" => login_token})
        |> PartnerUserAuth.fetch_partner_user_from_login_token([])

      refute get_session(conn, :embed_session_token)
    end

    test "does nothing when no login_token param is present", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{})
        |> PartnerUserAuth.fetch_partner_user_from_login_token([])

      refute get_session(conn, :embed_session_token)
    end

    test "does nothing with an invalid login_token", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{"login_token" => "garbage"})
        |> PartnerUserAuth.fetch_partner_user_from_login_token([])

      refute get_session(conn, :embed_session_token)
    end
  end

  describe "put_locale_from_browser/2" do
    test "uses JWT locale from assigns when present", %{conn: conn} do
      conn =
        conn
        |> assign(:locale, "fr")
        |> put_req_header("accept-language", "en-US,en;q=0.9")
        |> PartnerUserAuth.put_locale_from_browser([])

      assert conn.assigns.locale == "fr"
      assert Gettext.get_locale(PhoenixStarterKitWeb.Gettext) == "fr"
    end

    test "falls back to Accept-Language header when no JWT locale", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "es-MX,es;q=0.9")
        |> PartnerUserAuth.put_locale_from_browser([])

      assert conn.assigns.locale == "es-MX"
      assert Gettext.get_locale(PhoenixStarterKitWeb.Gettext) == "es-MX"
    end

    test "assigns nil locale when no JWT locale and no Accept-Language header", %{conn: conn} do
      conn = PartnerUserAuth.put_locale_from_browser(conn, [])

      assert is_nil(conn.assigns.locale)
    end

    test "assigns nil locale when Accept-Language header is blank", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "")
        |> PartnerUserAuth.put_locale_from_browser([])

      assert is_nil(conn.assigns.locale)
    end
  end

  describe "fetch_current_partner_user/2" do
    test "authenticates from the embed session token in the session", %{
      conn: conn,
      partner_user: partner_user
    } do
      partner = partner_fixture()
      token = embed_session_token_fixture(partner_user, partner)

      conn =
        conn
        |> put_session(:embed_session_token, token)
        |> put_session(:embed_locale, "es")
        |> PartnerUserAuth.fetch_current_partner_user([])

      assert conn.assigns.current_partner_user.id == partner_user.id
      assert conn.assigns.current_partner.id == partner.id
      assert conn.assigns.embed_session_token == token
      assert conn.assigns.locale == "es"
    end

    test "sets the platform of the partner for the embed session token", %{conn: conn, partner_user: partner_user} do
      token = embed_session_token_fixture(partner_user, partner_fixture(%{platform: :acme}))

      conn
      |> put_session(:embed_session_token, token)
      |> PartnerUserAuth.fetch_current_partner_user([])

      assert PhoenixStarterKitWeb.PlatformGettext.get_platform() == :acme
    end

    test "falls through to session token when the embed session token is invalid", %{
      conn: conn,
      partner_user: partner_user
    } do
      partner_user_token = Partners.generate_partner_user_session_token(partner_user)

      conn =
        conn
        |> put_session(:embed_session_token, "expired-or-bad")
        |> put_session(:partner_user_token, partner_user_token)
        |> PartnerUserAuth.fetch_current_partner_user([])

      assert conn.assigns.current_partner_user.id == partner_user.id
      refute conn.assigns[:embed_session_token]
    end

    test "does not authenticate with an embed session token older than 24 hours", %{
      conn: conn,
      partner_user: partner_user
    } do
      token = embed_session_token_fixture(partner_user, partner_fixture())
      age_tokens("embed_session", 86_401)

      conn =
        conn
        |> put_session(:embed_session_token, token)
        |> PartnerUserAuth.fetch_current_partner_user([])

      refute conn.assigns.current_partner_user
    end

    test "authenticates partner_user from session", %{conn: conn, partner_user: partner_user} do
      partner_user_token = Partners.generate_partner_user_session_token(partner_user)

      conn =
        conn
        |> put_session(:partner_user_token, partner_user_token)
        |> PartnerUserAuth.fetch_current_partner_user([])

      assert conn.assigns.current_partner_user.id == partner_user.id
    end

    test "does not authenticate if data is missing", %{conn: conn, partner_user: partner_user} do
      _ = Partners.generate_partner_user_session_token(partner_user)
      conn = PartnerUserAuth.fetch_current_partner_user(conn, [])
      refute get_session(conn, :partner_user_token)
      refute conn.assigns.current_partner_user
    end

    test "sets current partner from session", %{conn: conn, partner_user: partner_user} do
      partner = partner_fixture()
      partner_user_token = Partners.generate_partner_user_session_token(partner_user)

      # Connect partner user to partner
      {:ok, _} = Partners.connect_partner_user(partner, partner_user)

      conn =
        conn
        |> put_session(:partner_user_token, partner_user_token)
        |> put_session("current_partner_id", partner.id)
        |> PartnerUserAuth.fetch_current_partner_user([])

      assert conn.assigns.current_partner_user.id == partner_user.id
      assert conn.assigns.current_partner_user.partner.id == partner.id
    end

    test "falls back to first partner when no current_partner_id in session", %{
      conn: conn,
      partner_user: partner_user
    } do
      partner = partner_fixture()
      partner_user_token = Partners.generate_partner_user_session_token(partner_user)
      {:ok, _} = Partners.connect_partner_user(partner, partner_user)

      conn =
        conn
        |> put_session(:partner_user_token, partner_user_token)
        |> PartnerUserAuth.fetch_current_partner_user([])

      assert conn.assigns.current_partner_user.id == partner_user.id
      assert conn.assigns.current_partner_user.partner.id == partner.id
    end
  end

  describe "on_mount :ensure_authenticated" do
    test "authenticates current_partner_user based on a valid partner_user_token", %{
      conn: conn,
      partner_user: partner_user
    } do
      partner_user_token = Partners.generate_partner_user_session_token(partner_user)
      session = conn |> put_session(:partner_user_token, partner_user_token) |> get_session()

      {:cont, updated_socket} =
        PartnerUserAuth.on_mount(:ensure_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_partner_user.id == partner_user.id
    end

    test "authenticates current_partner_user from the embed session token", %{
      partner_user: partner_user
    } do
      token = embed_session_token_fixture(partner_user, partner_fixture())
      session = %{"embed_session_token" => token}

      {:cont, updated_socket} =
        PartnerUserAuth.on_mount(:ensure_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_partner_user.id == partner_user.id
    end

    test "halts with an invalid embed session token and no partner_user_token", %{conn: _conn} do
      session = %{"embed_session_token" => "bad-token"}

      socket = %LiveView.Socket{
        endpoint: PhoenixStarterKitWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} =
        PartnerUserAuth.on_mount(:ensure_authenticated, %{}, session, socket)

      assert updated_socket.assigns.current_partner_user == nil
    end

    test "uses the partner_user_token when the embed session token is not valid", %{
      conn: conn,
      partner_user: partner_user
    } do
      partner_user_token = Partners.generate_partner_user_session_token(partner_user)

      session =
        conn
        |> put_session(:partner_user_token, partner_user_token)
        |> put_session(:embed_session_token, "expired-or-bad")
        |> get_session()

      {:cont, updated_socket} =
        PartnerUserAuth.on_mount(:ensure_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_partner_user.id == partner_user.id
    end

    test "halts when the embed session token was deleted", %{partner_user: partner_user} do
      token = embed_session_token_fixture(partner_user, partner_fixture())
      :ok = Partners.delete_embed_session_token(token)
      session = %{"embed_session_token" => token}

      socket = %LiveView.Socket{
        endpoint: PhoenixStarterKitWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} =
        PartnerUserAuth.on_mount(:ensure_authenticated, %{}, session, socket)

      assert updated_socket.assigns.current_partner_user == nil
    end

    test "redirects to login page if there isn't a valid partner_user_token", %{conn: conn} do
      partner_user_token = "invalid_token"
      session = conn |> put_session(:partner_user_token, partner_user_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: PhoenixStarterKitWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} =
        PartnerUserAuth.on_mount(:ensure_authenticated, %{}, session, socket)

      assert updated_socket.assigns.current_partner_user == nil
    end

    test "redirects to login page if there isn't a partner_user_token", %{conn: conn} do
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: PhoenixStarterKitWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} =
        PartnerUserAuth.on_mount(:ensure_authenticated, %{}, session, socket)

      assert updated_socket.assigns.current_partner_user == nil
    end
  end

  describe "on_mount :mount_current_partner_user" do
    test "assigns current_partner_user from partner_user_token", %{
      conn: conn,
      partner_user: partner_user
    } do
      partner_user_token = Partners.generate_partner_user_session_token(partner_user)
      session = conn |> put_session(:partner_user_token, partner_user_token) |> get_session()

      {:cont, updated_socket} =
        PartnerUserAuth.on_mount(:mount_current_partner_user, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_partner_user.id == partner_user.id
    end

    test "assigns current_partner_user from the embed session token", %{partner_user: partner_user} do
      token = embed_session_token_fixture(partner_user, partner_fixture())
      session = %{"embed_session_token" => token}

      {:cont, updated_socket} =
        PartnerUserAuth.on_mount(:mount_current_partner_user, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_partner_user.id == partner_user.id
    end

    test "assigns nil when no tokens are present" do
      {:cont, updated_socket} =
        PartnerUserAuth.on_mount(:mount_current_partner_user, %{}, %{}, %LiveView.Socket{})

      assert updated_socket.assigns.current_partner_user == nil
    end
  end

  describe "live_session_data/1" do
    test "returns the embed session token and session data", %{conn: conn} do
      token = "some-embed-session-token"
      partner_user_token = "some-session-token"

      conn =
        conn
        |> assign(:embed_session_token, token)
        |> put_session(:partner_user_token, partner_user_token)
        |> put_session("current_partner_id", "some-partner-id")

      result = PartnerUserAuth.live_session_data(conn)

      assert result["embed_session_token"] == token
      assert result["partner_user_token"] == partner_user_token
      assert result["current_partner_id"] == "some-partner-id"
    end

    test "returns nils when no auth data is present", %{conn: conn} do
      result = PartnerUserAuth.live_session_data(conn)

      assert result["embed_session_token"] == nil
      assert result["partner_user_token"] == nil
      assert result["current_partner_id"] == nil
    end
  end

  describe "require_authenticated_partner_user/2" do
    test "redirects if partner_user is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> PartnerUserAuth.require_authenticated_partner_user([])
      assert conn.halted

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> PartnerUserAuth.require_authenticated_partner_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :partner_user_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> PartnerUserAuth.require_authenticated_partner_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :partner_user_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> PartnerUserAuth.require_authenticated_partner_user([])

      assert halted_conn.halted
      refute get_session(halted_conn, :partner_user_return_to)
    end

    test "shows the expired page for a login_token that was not accepted", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{"login_token" => "used-or-expired"})
        |> fetch_flash()
        |> put_private(:phoenix_endpoint, PhoenixStarterKitWeb.Endpoint)
        |> put_private(:phoenix_format, "html")
        |> PartnerUserAuth.require_authenticated_partner_user([])

      assert conn.halted
      assert html_response(conn, 200) =~ "Session Expired"
    end

    test "does not redirect if partner_user is authenticated", %{
      conn: conn,
      partner_user: partner_user
    } do
      conn =
        conn
        |> assign(:current_partner_user, partner_user)
        |> PartnerUserAuth.require_authenticated_partner_user([])

      refute conn.halted
      refute conn.status
    end
  end
end
