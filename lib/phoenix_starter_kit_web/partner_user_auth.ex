defmodule PhoenixStarterKitWeb.PartnerUserAuth do
  @moduledoc """
  This module handles authentication for partner users.

  It provides functions for logging in and out partner users, as well as
  plugs for authenticating requests and LiveView sessions. It also handles
  setting the current partner for a partner user.

  Authentication flow for iframe-embedded contexts (e.g. peek-pro app-store):
  1. The parent app POSTs a peek-auth token to /peek-pro/settings
  2. EmbedsController verifies the token, upserts the partner user, and
     creates a one-time login token that is valid for 60 seconds
  3. The user is redirected to /settings?login_token=<token>&locale=<locale>
  4. `fetch_partner_user_from_login_token` exchanges the login token for an
     embed session token (a DB row, valid for 24 hours) and puts it in the session
  5. `fetch_current_partner_user` gets the user for the embed session token
  6. `live_session_data` embeds the embed session token into the LiveView's
     phx-session token (serialized into the HTML), so it's available on
     longpoll/WebSocket connect WITHOUT cookies
  7. `on_mount` checks the embed session token in the DB — no cookie session needed

  Logout and uninstall delete the embed session tokens, and the open LiveViews
  that use them redirect to "/".
  """
  use PhoenixStarterKitWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller
  import PhoenixStarterKitWeb.PlatformGettext

  alias PhoenixStarterKit.Partners
  alias PhoenixStarterKit.Repo
  alias PhoenixStarterKitWeb.PlatformGettext

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
    embed_session_token = get_session(conn, :embed_session_token)
    embed_session_token && Partners.delete_embed_session_token(embed_session_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      PhoenixStarterKitWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> redirect(to: ~p"/")
  end

  @doc """
  Plug that exchanges the one-time `login_token` query param for an embed
  session token. This is the entry point for iframe-based authentication
  where third-party cookies are blocked (Safari, incognito).

  It renews the session and puts the embed session token and the `locale`
  param in it.
  `fetch_current_partner_user` reads them in the same request, and
  `live_session_data` embeds them in the LiveView's phx-session token.
  A login token that is not valid changes nothing.
  """
  def fetch_partner_user_from_login_token(conn, _opts) do
    with login_token when is_binary(login_token) <- conn.params["login_token"],
         {:ok, embed_session_token} <- Partners.exchange_embed_login_token(login_token) do
      conn
      |> renew_session()
      |> put_session(:embed_session_token, embed_session_token)
      |> put_session(:embed_locale, embed_locale(conn.params["locale"]))
    else
      _ -> conn
    end
  end

  defp embed_locale(locale) when is_binary(locale) and locale != "", do: locale
  defp embed_locale(_locale), do: nil

  @doc """
  Authenticates the partner_user from the embed session token in the session,
  else from the partner_user session token.
  """
  def fetch_current_partner_user(conn, _opts) do
    with token when is_binary(token) <- get_session(conn, :embed_session_token),
         %{} = partner_user <- Partners.get_partner_user_by_embed_session_token(token) do
      set_sentry_context(partner_user)
      PlatformGettext.put_platform(partner_user.partner.platform)

      conn
      |> assign(:current_partner_user, partner_user)
      |> assign(:current_partner, partner_user.partner)
      |> assign(:embed_session_token, token)
      |> assign(:locale, get_session(conn, :embed_locale))
    else
      _ -> fetch_partner_user_from_session(conn)
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

  This is the key mechanism for cookie-free auth: the embed session token is
  serialized into the HTML and sent back on longpoll/WebSocket connect,
  completely bypassing the cookie-based Plug session.

  Used by the `session:` option on `live_session` in the router.
  """
  def live_session_data(conn) do
    partner_user_token = get_session(conn, :partner_user_token)

    %{
      # The embed session token — checked in the DB in on_mount.
      # This is embedded in the HTML and doesn't depend on cookies.
      "embed_session_token" => conn.assigns[:embed_session_token],
      # Keep session-based keys as fallback for first-party contexts
      # where cookies work normally.
      "partner_user_token" => partner_user_token,
      "current_partner_id" => get_session(conn, "current_partner_id"),
      "locale" => conn.assigns[:locale]
    }
  end

  @doc """
  Plug that resolves the Gettext locale for the current request.

  Priority:
    1. JWT locale from `:locale` assign (set by fetch_current_partner_user)
    2. Browser locale parsed from the Accept-Language request header

  Assigns `:locale` on the conn so `live_session_data/1` can carry it into
  the LiveView phx-session, where `mount_current_partner_user/2` re-applies it.
  """
  def put_locale_from_browser(conn, _opts) do
    locale = conn.assigns[:locale] || browser_locale(conn)
    PlatformGettext.put_locale(locale)
    assign(conn, :locale, locale)
  end

  defp browser_locale(conn) do
    case get_req_header(conn, "accept-language") do
      [header | _] ->
        header
        |> String.split([",", ";"])
        |> List.first()
        |> String.trim()
        |> case do
          "" -> nil
          locale -> locale
        end

      [] ->
        nil
    end
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
        |> Phoenix.LiveView.put_flash(:error, t("You must log in to access this page."))
        |> Phoenix.LiveView.redirect(to: ~p"/")

      {:halt, socket}
    end
  end

  def on_mount(:mount_current_partner_user, _params, session, socket) do
    {:cont, mount_current_partner_user(socket, session)}
  end

  defp mount_current_partner_user(socket, session) do
    {partner_user, locale} = resolve_session(session)

    socket =
      socket
      |> Phoenix.Component.assign_new(:current_partner_user, fn -> partner_user end)
      |> Phoenix.Component.assign_new(:locale, fn -> locale end)

    # Set platform and Sentry context after assign_new so it always runs in the
    # current process — LiveView runs in a separate process from the HTTP conn,
    # so process-dictionary state (Sentry, PlatformGettext) must be re-set here.
    # JWT locale overrides browser-language detection downstream apps may have applied.
    PlatformGettext.put_locale(socket.assigns[:locale])

    if partner_user = socket.assigns[:current_partner_user] do
      if partner_user.partner do
        PlatformGettext.put_platform(partner_user.partner.platform)
      end

      set_sentry_context(partner_user)
    end

    socket
    |> watch_embed_session(session["embed_session_token"])
    |> safe_on_mount()
  end

  # Redirects the connected LiveView to "/" when its embed session token is
  # deleted (logout or uninstall).
  defp watch_embed_session(socket, embed_session_token) when is_binary(embed_session_token) do
    topic = Partners.embed_session_topic(embed_session_token)

    if topic && socket.assigns.current_partner_user && Phoenix.LiveView.connected?(socket) do
      Phoenix.PubSub.subscribe(PhoenixStarterKit.PubSub, topic)
      Phoenix.LiveView.attach_hook(socket, :embed_session_revoked, :handle_info, &handle_embed_session_revoked/2)
    else
      socket
    end
  end

  defp watch_embed_session(socket, _embed_session_token), do: socket

  defp handle_embed_session_revoked(:embed_session_revoked, socket) do
    socket =
      socket
      |> Phoenix.LiveView.put_flash(:error, t("You must log in to access this page."))
      |> Phoenix.LiveView.redirect(to: ~p"/")

    {:halt, socket}
  end

  defp handle_embed_session_revoked(_message, socket), do: {:cont, socket}

  defp resolve_session(session) do
    embed_partner_user =
      if embed_session_token = session["embed_session_token"],
        do: Partners.get_partner_user_by_embed_session_token(embed_session_token)

    cond do
      embed_partner_user ->
        {embed_partner_user, session["locale"]}

      partner_user_token = session["partner_user_token"] ->
        partner_user =
          Partners.get_partner_user_by_session_token(
            partner_user_token,
            session["current_partner_id"]
          )

        {partner_user, session["locale"]}

      true ->
        {nil, session["locale"]}
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
    cond do
      conn.assigns[:current_partner_user] ->
        conn

      # A used or expired login token, e.g. a reload in a Safari iframe that
      # has no session cookie: show the page that reloads the Peek Pro parent,
      # which gets a new login token.
      match?(%{"login_token" => _}, conn.params) ->
        conn
        |> put_root_layout(false)
        |> put_layout(false)
        |> put_view(PhoenixStarterKitWeb.PeekPro.EmbedsHTML)
        |> render(:expired)
        |> halt()

      true ->
        conn
        |> put_flash(:error, t("You must log in to access this page."))
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
