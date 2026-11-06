defmodule PhoenixStarterKitWeb.Demo.DemoRoutes do
  @moduledoc """
  Turns the `/demo` pages on or off.

  The demo pages run only when `config :phoenix_starter_kit, :demo_routes` is `true`.
  `config/dev.exs` and `config/test.exs` set it. Other environments get a 404.

  Use it as a plug in the router and as an `on_mount` hook in the `live_session`.
  The hook is necessary because a LiveView socket mount does not go through the router plugs.
  """
  @behaviour Plug

  import Plug.Conn

  @doc "Returns true when the demo pages are on."
  def enabled?, do: Application.get_env(:phoenix_starter_kit, :demo_routes, false) == true

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    if enabled?() do
      conn
    else
      conn
      |> send_resp(:not_found, "Not Found")
      |> halt()
    end
  end

  def on_mount(:default, _params, _session, socket) do
    if enabled?() do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    end
  end
end
