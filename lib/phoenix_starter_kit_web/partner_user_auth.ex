defmodule PhoenixStarterKitWeb.PartnerUserAuth do
  @moduledoc """
  This module handles authentication for partner users.

  It provides functions for logging in and out partner users, as well as
  plugs for authenticating requests and LiveView sessions. It also handles
  setting the current partner for a partner user.
  """
  use PhoenixStarterKitWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

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

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn, fields_to_save \\ []) do
    # Store any session data you want to preserve
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
  Authenticates the partner_user by looking into the session
  and remember me token.
  """
  def fetch_current_partner_user(conn, _opts) do
    {partner_user_token, conn} = ensure_partner_user_token(conn)
    maybe_partner_id = get_session(conn, "current_partner_id")

    partner_user =
      partner_user_token && Partners.get_partner_user_by_session_token(partner_user_token)

    # If no partner_user, return early with nil assignment
    if partner_user do
      # Set the current partner for the partner_user
      partner_user = set_partner_for_user(partner_user, maybe_partner_id)

      # Set Sentry context and return with partner_user assignment
      set_sentry_context(partner_user)
      return_with_partner_user(conn, partner_user)
    else
      return_with_partner_user(conn, nil)
    end
  end

  # Helper to set the current partner for a partner_user
  defp set_partner_for_user(partner_user, maybe_partner_id) do
    if maybe_partner_id do
      Partners.set_current_partner(partner_user, maybe_partner_id)
    else
      # If no current_partner_id, use the first partner
      partner_user = Repo.preload(partner_user, :partners)
      partner = partner_user.partners |> Enum.sort_by(& &1.inserted_at, :desc) |> List.first()
      Partners.set_current_partner(partner_user, partner)
    end
  end

  # Helper to set Sentry context
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

  # Helper to return conn with partner_user assignment and set platform
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
        if partner_user_token = session["partner_user_token"] do
          Partners.get_partner_user_by_session_token(
            partner_user_token,
            session["current_partner_id"]
          )
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
