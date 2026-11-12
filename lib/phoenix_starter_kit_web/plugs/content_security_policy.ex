defmodule PhoenixStarterKitWeb.Plugs.ContentSecurityPolicy do
  @moduledoc """
  Sets the `content-security-policy` response header.

  The header keeps `base-uri 'self'` and lets only the app itself and the
  hosts in `config :phoenix_starter_kit, :frame_ancestors` show the app in a
  frame. Set the `FRAME_ANCESTORS` env var (space-separated hosts) to change
  the list at runtime.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    put_resp_header(conn, "content-security-policy", policy())
  end

  @doc "Returns the policy for the configured frame ancestors."
  def policy do
    ancestors = Enum.join(["'self'" | Application.fetch_env!(:phoenix_starter_kit, :frame_ancestors)], " ")
    "base-uri 'self'; frame-ancestors #{ancestors}"
  end
end
