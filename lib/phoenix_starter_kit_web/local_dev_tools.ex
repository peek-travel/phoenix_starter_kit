defmodule PhoenixStarterKitWeb.LocalDevTools do
  @moduledoc """
  Keeps the dev tools for local requests only.

  `bin/dev` (cloudflared) and ngrok forward requests from a public hostname to
  `localhost:4000`, so `remote_ip` is local for each request. These proxies add
  forwarding headers (see `proxied?/1`). For a request with one of these headers:

    * `/tidewave/*`, `/dev/*`, `/__plug__/*` and `/phoenix/*` return 404
      (Tidewave, LiveDashboard, mailbox preview, Plug.Debugger actions, live reload).
    * An error returns a plain status text, not the Plug.Debugger page.
    * The code reloader's compile-error page returns a plain status text.
    * The LiveDashboard LiveView does not mount over the `/live` socket
      (`on_mount/4`). The socket sees only `x-` headers; cloudflared and ngrok
      always add `x-forwarded-for`.
    * The router's `/dev` scope also uses this module as a plug, after the
      router has decoded the path.

  A request with none of these headers works as before.

  For a proxied request, each 500 HTML response becomes plain text, because the
  code reloader's page cannot be told apart from other 500 HTML pages.

  The endpoint uses this module only in dev:

      if Application.compile_env(:phoenix_starter_kit, :dev_routes) do
        use PhoenixStarterKitWeb.LocalDevTools
      end

  Put it after `use Phoenix.Endpoint`.
  """

  @behaviour Plug

  import Plug.Conn

  @proxy_headers ["cf-connecting-ip", "cf-ray", "forwarded", "x-forwarded-for", "x-forwarded-host"]
  @local_only_segments ["tidewave", "dev", "__plug__", "phoenix"]

  defmacro __using__(_opts) do
    quote do
      @before_compile PhoenixStarterKitWeb.LocalDevTools

      # Overrides Plug.Builder's call/2. Plug.Debugger wraps this function.
      def call(conn, opts) do
        PhoenixStarterKitWeb.LocalDevTools.call_inner(conn, fn conn -> super(conn, opts) end)
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      defoverridable call: 2

      # Wraps Phoenix.Endpoint's call/2 and Plug.Debugger.
      def call(conn, opts) do
        PhoenixStarterKitWeb.LocalDevTools.call_outer(conn, fn conn -> super(conn, opts) end)
      end
    end
  end

  @doc """
  Returns true when the request headers contain a forwarding header.
  """
  def proxied?(%Plug.Conn{req_headers: headers}), do: proxied?(headers)
  def proxied?(headers) when is_list(headers), do: Enum.any?(headers, fn {name, _} -> name in @proxy_headers end)

  @impl Plug
  def init(opts), do: opts

  @doc """
  Plug for a router scope. Returns 404 for a proxied request.
  """
  @impl Plug
  def call(conn, _opts) do
    if proxied?(conn), do: conn |> send_plain(404) |> halt(), else: conn
  end

  @doc false
  def call_outer(conn, next) do
    cond do
      not proxied?(conn) -> next.(conn)
      local_only_path?(conn) -> conn |> send_plain(404) |> halt()
      true -> conn |> register_before_send(&plain_compile_error/1) |> next.()
    end
  end

  @doc false
  def call_inner(conn, next) do
    if proxied?(conn) do
      try do
        next.(conn)
      rescue
        error in Plug.Conn.WrapperError ->
          send_plain_and_reraise(error.conn, error.kind, error.reason, error.stack)
      catch
        kind, reason ->
          send_plain_and_reraise(conn, kind, reason, __STACKTRACE__)
      end
    else
      next.(conn)
    end
  end

  @doc """
  LiveView `on_mount` hook. Halts the mount for a proxied connection.
  """
  def on_mount(:local_only, _params, _session, socket) do
    headers = Phoenix.LiveView.get_connect_info(socket, :x_headers) || []

    if proxied?(headers) do
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    else
      {:cont, socket}
    end
  end

  # Decode the segment as Phoenix.Router does, so "/%64ev" matches "dev".
  defp local_only_path?(%Plug.Conn{path_info: [segment | _]}), do: URI.decode(segment) in @local_only_segments
  defp local_only_path?(_conn), do: false

  # Phoenix.CodeReloader sends a 500 HTML page with the compiler output.
  defp plain_compile_error(%Plug.Conn{status: 500} = conn) do
    case get_resp_header(conn, "content-type") do
      ["text/html" <> _ | _] -> plain_body(conn, 500)
      _ -> conn
    end
  end

  defp plain_compile_error(conn), do: conn

  defp send_plain_and_reraise(conn, kind, reason, stack) do
    unless sent?() do
      status = kind |> Exception.normalize(reason, stack) |> status()
      send_plain(conn, status)
    end

    :erlang.raise(kind, reason, stack)
  end

  defp status(exception) when is_exception(exception), do: Plug.Exception.status(exception)
  defp status(_reason), do: 500

  defp sent? do
    receive do
      {:plug_conn, :sent} = message ->
        send(self(), message)
        true
    after
      0 -> false
    end
  end

  defp send_plain(conn, status), do: conn |> plain_body(status) |> send_resp()

  defp plain_body(conn, status) do
    conn
    |> put_resp_content_type("text/plain")
    |> resp(status, Plug.Conn.Status.reason_phrase(status))
  end
end
