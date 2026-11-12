defmodule PhoenixStarterKitWeb.SentryScrubber do
  @moduledoc """
  Removes request data from Sentry events.

  Sentry's default scrubbers remove the `authorization` and `cookie` headers,
  and each param whose name contains `auth` or `token` (for example
  `peek-auth`, `login_token`). This module also removes the `x-peek-auth`
  header.
  """

  @scrubbed_headers ["x-peek-auth"]

  @doc "Returns the request headers to send to Sentry."
  def scrub_headers(conn) do
    conn
    |> Sentry.PlugContext.default_header_scrubber()
    |> Map.drop(@scrubbed_headers)
  end
end
