defmodule PhoenixStarterKitWeb.PartnerUserAuth do
  @moduledoc """
  This module handles authentication for partner users.

  It provides functions for logging in and out partner users, as well as
  plugs for authenticating requests and LiveView sessions. It also handles
  setting the current partner for a partner user.

  Authentication flow for iframe-embedded contexts (e.g. peek-pro app-store):
  1. The parent app POSTs a peek-auth token to /peek-pro/settings
  2. EmbedsController verifies the token, upserts the partner user, and
     generates a signed Phoenix.Token containing {partner_user_id, partner_id}
  3. The user is redirected to /settings?auth_token=<token>
  4. `fetch_partner_user_from_auth_token` verifies the token and assigns the user
  5. `live_session_data` embeds the auth_token into the LiveView's phx-session
     token (serialized into the HTML), so it's available on longpoll/WebSocket
     connect WITHOUT cookies
  6. `on_mount` verifies the auth_token directly — no cookie session needed
  """
  use PhoenixStarterKitWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias PhoenixStarterKit.Partners
  alias PhoenixStarterKit.Repo
  alias PhoenixStarterKitWeb.PlatformGettext

  # Auth token valid for 24 hours — needs to survive the full LiveView session
  # including longpoll reconnects. Re-issued on every entry from peek-pro.
  @auth_token_max_age 86_400

  @doc """
  Logs the partner_user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in_partner_user(conn, partner_user) do
    token = Partners.generate_partner_user_session_token(partner_user)
    partner_user_return_to = get_session(conn, :partner_user_return_to)

    conn
    |> renew_session(["current_partner_id"])
    |> put_token_in_session(token)
    |> redirect(to: partner_user_return_to || signed_in_path(conn))
  end

  defp renew_session(conn, fields_to_save \\ []) do
    fields = Map.new(fields_to_save, &{&1, get_session(conn, &1)})

    delete_csrf_token()

    conn =
      conn
      |> configure_session(renew: true)
      |> clear_session()

    Enum.reduce(fields, conn, fn {key, value}, conn ->
      put_session(conn, key, value)
    end)
  end

  @doc """
  Logs the partner_user out.

  It clears all session data for safety. See renew_session. This is currently
  not needed since login is automatically handled by iframe but might be useful
  to keep around in case we need it; technically speaking, logging the partner
  out at some point could add value/security.
  """
  def log_out_partner_user(conn) do
    partner_user_token = get_session(conn, :partner_user_token)
    partner_user_token && Partners.delete_partner_user_session_token(partner_user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      PhoenixStarterKitWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> redirect(to: ~p"/")
  end

  @doc """
  Plug that authenticates a partner user from a signed auth_token in the
  query params. This is the entry point for iframe-based authentication
  where third-party cookies are blocked (Safari, incognito).

  Stores the auth_token in conn assigns so `live_session_data` can embed
  it in the LiveView's phx-session token — completely bypassing cookies.
  """
  def fetch_partner_user_from_auth_token(conn, _opts) do
    with token when is_binary(token) <- conn.params["auth_token"],
         {:ok, {partner_user_id, partner_id}} <-
           Phoenix.Token.verify(PhoenixStarterKitWeb.Endpoint, "partner_auth", token, max_age: @auth_token_max_age),
         %{} = partner_user <- Partners.get_partner_user(partner_user_id) do
      partner_user = Partners.set_current_partner(partner_user, partner_id)

      conn
      |> assign(:current_partner_user, partner_user)
      |> assign(:current_partner, partner_user.partner)
      |> assign(:auth_token, token)
      # Persist auth_token in the session so it survives page reloads when
      # the URL no longer contains it. In an iframe on Safari the session
      # cookie is blocked,
      # but LiveView handles navigation without full reloads there. When
      # the page is opened in a new tab it becomes first-party and the
      # cookie works normally.
      |> put_session(:auth_token, token)
    else
      _ -> conn
    end
  end

  @doc """
  Authenticates the partner_user by looking into the session.
  Skips if :current_partner_user is already assigned (e.g. by auth token plug).
  """
  def fetch_current_partner_user(conn, _opts) do
    if conn.assigns[:current_partner_user] do
      conn
    else
      # First try to restore from a session-persisted auth_token (set by
      # fetch_partner_user_from_auth_token on a previous request).
      with token when is_binary(token) <- get_session(conn, :auth_token),
           {:ok, {partner_user_id, partner_id}} <-
             Phoenix.Token.verify(PhoenixStarterKitWeb.Endpoint, "partner_auth", token, max_age: @auth_token_max_age),
           %{} = partner_user <- Partners.get_partner_user(partner_user_id) do
        partner_user = Partners.set_current_partner(partner_user, partner_id)
        set_sentry_context(partner_user)

        conn
        |> assign(:current_partner_user, partner_user)
        |> assign(:current_partner, partner_user.partner)
        |> assign(:auth_token, token)
      else
        _ -> fetch_partner_user_from_session(conn)
      end
    end
  end

  defp fetch_partner_user_from_session(conn) do
    {partner_user_token, conn} = ensure_partner_user_token(conn)
    maybe_partner_id = get_session(conn, "current_partner_id")

    partner_user =
      partner_user_token && Partners.get_partner_user_by_session_token(partner_user_token)

    if partner_user do
      partner_user = set_partner_for_user(partner_user, maybe_partner_id)
      set_sentry_context(partner_user)
      return_with_partner_user(conn, partner_user)
    else
      return_with_partner_user(conn, nil)
    end
  end

  defp set_partner_for_user(partner_user, maybe_partner_id) do
    if maybe_partner_id do
      Partners.set_current_partner(partner_user, maybe_partner_id)
    else
      partner_user = Repo.preload(partner_user, :partners)
      partner = partner_user.partners |> Enum.sort_by(& &1.inserted_at, :desc) |> List.first()
      Partners.set_current_partner(partner_user, partner)
    end
  end

  defp set_sentry_context(partner_user) do
    partner_name =
      if partner_user.partner,
        do: partner_user.partner.name,
        else: "-- Missing Partner Name --"

    Sentry.Context.set_user_context(%{
      partner_name: partner_name,
      id: partner_user.id
    })
  end

  defp return_with_partner_user(conn, partner_user) do
    if partner_user && partner_user.partner do
      PlatformGettext.put_platform(partner_user.partner.platform)
    end

    assign(conn, :current_partner_user, partner_user)
  end

  defp ensure_partner_user_token(conn) do
    if token = get_session(conn, :partner_user_token) do
      {token, conn}
    else
      {nil, conn}
    end
  end

  @doc """
  Returns session data to embed in the LiveView's phx-session token.

  This is the key mechanism for cookie-free auth: the auth_token is
  serialized into the HTML and sent back on longpoll/WebSocket connect,
  completely bypassing the cookie-based Plug session.

  Used by the `session:` option on `live_session` in the router.
  """
  def live_session_data(conn) do
    auth_token = conn.assigns[:auth_token]
    partner_user_token = get_session(conn, :partner_user_token)

    %{
      # The signed Phoenix.Token — verified directly in on_mount.
      # This is embedded in the HTML and doesn't depend on cookies.
      "auth_token" => auth_token,
      # Keep session-based keys as fallback for first-party contexts
      # where cookies work normally.
      "partner_user_token" => partner_user_token,
      "current_partner_id" => get_session(conn, "current_partner_id")
    }
  end

  @doc """
  Handles mounting and authenticating the current_partner_user in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_partner_user` - Assigns current_partner_user
      to socket assigns based on partner_user_token, or nil if
      there's no partner_user_token or no matching partner_user.

    * `:ensure_authenticated` - Authenticates the partner_user from the session,
      and assigns the current_partner_user to socket assigns based
      on partner_user_token.
      Redirects to login page if there's no logged partner_user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the current_partner_user:

      defmodule PhoenixStarterKitWeb.PageLive do
        use PhoenixStarterKitWeb, :live_view

        on_mount {PhoenixStarterKitWeb.PartnerUserAuth, :mount_current_partner_user}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{PhoenixStarterKitWeb.PartnerUserAuth, :ensure_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_partner_user(socket, session)

    if socket.assigns.current_partner_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/")

      {:halt, socket}
    end
  end

  def on_mount(:mount_current_partner_user, _params, session, socket) do
    {:cont, mount_current_partner_user(socket, session)}
  end

  defp mount_current_partner_user(socket, session) do
    socket =
      Phoenix.Component.assign_new(socket, :current_partner_user, fn ->
        cond do
          auth_token = session["auth_token"] ->
            verify_auth_token(auth_token)

          partner_user_token = session["partner_user_token"] ->
            Partners.get_partner_user_by_session_token(
              partner_user_token,
              session["current_partner_id"]
            )

          true ->
            nil
        end
      end)

    # Set platform after assign_new so it always runs in the current process
    if partner_user = socket.assigns[:current_partner_user] do
      if partner_user.partner do
        PlatformGettext.put_platform(partner_user.partner.platform)
      end
    end

    safe_on_mount(socket)
  end

  defp verify_auth_token(token) do
    case Phoenix.Token.verify(PhoenixStarterKitWeb.Endpoint, "partner_auth", token, max_age: @auth_token_max_age) do
      {:ok, {partner_user_id, partner_id}} ->
        case Partners.get_partner_user(partner_user_id) do
          nil -> nil
          partner_user -> Partners.set_current_partner(partner_user, partner_id)
        end

      _ ->
        nil
    end
  end

  defp safe_on_mount(socket) do
    # This is only for tests and annoying; getting an error about how the live
    # view isn't mounted because of how the tests are scaffolded for live view.
    # Because of this I'm just rescuing and moving on.
    Phoenix.LiveView.attach_hook(
      socket,
      :save_request_path,
      :handle_params,
      &save_request_path/3
    )
  rescue
    RuntimeError ->
      # This is a workaround for a bug in Phoenix LiveView
      # where the :handle_params hook is not called when
      # the socket is mounted with a session.
      socket
  end

  defp save_request_path(_params, url, socket) do
    {:cont, Phoenix.Component.assign(socket, :request_uri, URI.parse(url))}
  end

  @doc """
  Used for routes that require the partner_user to be authenticated.

  If you want to enforce the partner_user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_partner_user(conn, _opts) do
    if conn.assigns[:current_partner_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/")
      |> halt()
    end
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:partner_user_token, token)
    |> put_session(:live_socket_id, "partner_users_sessions:#{Base.url_encode64(token)}")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :partner_user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: ~p"/settings"
end
