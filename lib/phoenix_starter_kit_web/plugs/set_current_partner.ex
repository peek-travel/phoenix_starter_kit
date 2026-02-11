defmodule PhoenixStarterKitWeb.Plugs.SetCurrentPartner do
  @moduledoc """
  This plug sets the current partner in the connection assigns based on the
  `peek_install_id` present in the connection assigns. It fetches the partner
  from the database using the `PhoenixStarterKit.Partners.get_partner_by_peek_install_id/1`
  function and assigns it to the connection.
  If no partner is found, it simply returns the connection without any changes.
  This is useful for ensuring that the current partner is available in the
  connection assigns for use in controllers and views.

  Also sets the platform in PlatformGettext for UI translations.
  """
  import Plug.Conn
  alias PhoenixStarterKit.Partners
  alias PhoenixStarterKitWeb.PlatformGettext

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{assigns: %{peek_install_id: peek_install_id}} = conn, _opts)
      when is_binary(peek_install_id) do
    partner = Partners.get_partner_by_peek_install_id(peek_install_id)

    if partner, do: PlatformGettext.put_platform(partner.platform)

    conn
    |> assign(:current_partner, partner)
    |> put_session("current_partner_id", if(partner, do: partner.id))
  end

  def call(conn, _opts) do
    if current_partner_id = get_session(conn, "current_partner_id") do
      partner = Partners.get_partner!(current_partner_id)
      PlatformGettext.put_platform(partner.platform)

      assign(conn, :current_partner, partner)
    else
      assign(conn, :current_partner, nil)
    end
  end
end
