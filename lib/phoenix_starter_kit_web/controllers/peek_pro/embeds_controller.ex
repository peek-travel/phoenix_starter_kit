defmodule PhoenixStarterKitWeb.PeekPro.EmbedsController do
  @moduledoc """
  This controller is used to handle the landing page for the Peek Pro
  embedded route.
  """
  use PhoenixStarterKitWeb, :controller

  def landing(%{assigns: %{current_partner: nil, peek_install_id: peek_install_id}} = conn, params) when is_binary(peek_install_id) do
    # This SHOULDN'T be needed but there could be race conditions where the
    # install webhook is delayed so we haven't setup the partner yet.
    # The idea is to try again and again until it works and if after a minute or
    # so it still doesn't we can give up.

    attempt = Map.get(params, "attempt", "0") |> String.to_integer()

    next_attempt = attempt + 1
    current_path = conn.request_path
    redirect_url = "#{current_path}?attempt=#{next_attempt}"

    # Render the loading template with the redirect URL
    conn
    |> fetch_session()
    |> fetch_flash()
    |> put_root_layout(false)
    |> put_layout(false)
    |> render(:loading, redirect_url: redirect_url, next_attempt: next_attempt)
  end

  def landing(
        %{
          assigns: %{
            peek_install_id: peek_install_id,
            current_partner: current_partner,
            peek_account_user: %PeekAppSDK.AccountUser{} = peek_account_user
          }
        } = conn,
        _params
      )
      when is_binary(peek_install_id) do
    partner_user = PhoenixStarterKit.Partners.upsert_for_peek_account_user(current_partner, peek_account_user)

    auth_token =
      Phoenix.Token.sign(PhoenixStarterKitWeb.Endpoint, "partner_auth", {
        partner_user.id,
        current_partner.id
      })

    redirect(conn, to: ~p"/settings?auth_token=#{auth_token}")
  end

  def landing(conn, _params) do
    conn
    |> fetch_session()
    |> fetch_flash()
    |> put_root_layout(false)
    |> put_layout(false)
    |> render(:expired)
  end
end
