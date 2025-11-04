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

    test "works even if partner_user is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> PartnerUserAuth.log_out_partner_user()
      refute get_session(conn, :partner_user_token)
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_current_partner_user/2" do
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
