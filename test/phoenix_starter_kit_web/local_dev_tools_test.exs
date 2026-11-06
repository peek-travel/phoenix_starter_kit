defmodule PhoenixStarterKitWeb.LocalDevToolsTest do
  use ExUnit.Case, async: true

  defmodule Actions do
    @moduledoc false
    import Plug.Conn

    def init(action), do: action

    def call(conn, :ok), do: send_resp(conn, 200, "ok")
    def call(_conn, :raise), do: raise("raised in the test router")
    def call(_conn, :throw), do: throw(:thrown_in_the_test_router)

    def call(conn, :send_then_raise) do
      send_resp(conn, 200, "sent")
      raise "raised after the response"
    end

    def call(conn, :compile_error) do
      Phoenix.CodeReloader.call(conn, reloader: fn _endpoint, _opts -> {:error, "compiler output"} end)
    end

    def call(_conn, :bad_request), do: raise(Plug.BadRequestError)

    def call(conn, :json_error) do
      conn |> put_resp_content_type("application/json") |> send_resp(500, ~s({"error":"json"}))
    end
  end

  defmodule Router do
    use Phoenix.Router

    pipeline :local_dev_tools do
      plug PhoenixStarterKitWeb.LocalDevTools
    end

    scope "/tools" do
      pipe_through :local_dev_tools
      get "/page", Actions, :ok
    end

    get "/", Actions, :ok
    get "/devices", Actions, :ok
    get "/dev/dashboard", Actions, :ok
    get "/tidewave/mcp", Actions, :ok
    get "/phoenix/live_reload/frame", Actions, :ok
    get "/raise", Actions, :raise
    get "/throw", Actions, :throw
    get "/send-then-raise", Actions, :send_then_raise
    get "/compile-error", Actions, :compile_error
    get "/json-error", Actions, :json_error
    get "/bad-request", Actions, :bad_request
  end

  Application.put_env(:phoenix_starter_kit, __MODULE__.Endpoint,
    secret_key_base: String.duplicate("a", 64),
    debug_errors: true,
    render_errors: [formats: [html: PhoenixStarterKitWeb.ErrorHTML], layout: false],
    server: false
  )

  defmodule Endpoint do
    use Sentry.PlugCapture
    use Phoenix.Endpoint, otp_app: :phoenix_starter_kit
    use PhoenixStarterKitWeb.LocalDevTools

    plug Router
  end

  import Phoenix.ConnTest
  import Plug.Conn

  alias PhoenixStarterKitWeb.LocalDevTools

  @endpoint Endpoint

  setup_all do
    start_supervised!(Endpoint)
    :ok
  end

  defp proxied_conn(header \\ "cf-connecting-ip") do
    put_req_header(build_conn(), header, "203.0.113.7")
  end

  describe "proxied requests" do
    test "get 404 for each local-only path" do
      for path <- ["/tidewave/mcp", "/dev/dashboard", "/phoenix/live_reload/frame"] do
        conn = get(proxied_conn(), path)
        assert conn.status == 404, path
        assert conn.resp_body == "Not Found"
        assert conn.halted
      end

      conn = post(proxied_conn(), "/__plug__/debugger/action", %{"encoded_handler" => "x"})
      assert conn.status == 404
    end

    test "get 404 for a percent-encoded local-only path" do
      assert get(proxied_conn(), "/%64ev/dashboard").status == 404
      assert get(proxied_conn(), "/%74idewave/mcp").status == 404
    end

    test "get 404 from the router plug" do
      conn = get(proxied_conn(), "/tools/page")
      assert conn.status == 404
      assert conn.resp_body == "Not Found"
    end

    test "get the plain status of a 4xx error" do
      {400, _headers, body} = assert_error_sent(400, fn -> get(proxied_conn(), "/bad-request") end)
      assert body == "Bad Request"
    end

    test "each forwarding header marks the request as proxied" do
      for header <- ["cf-connecting-ip", "cf-ray", "forwarded", "x-forwarded-for", "x-forwarded-host"] do
        assert get(proxied_conn(header), "/dev/dashboard").status == 404, header
      end
    end

    test "reach app paths" do
      assert get(proxied_conn(), "/").resp_body == "ok"
      assert get(proxied_conn(), "/devices").resp_body == "ok"
    end

    test "get a plain error, not the debugger page" do
      {500, headers, body} = assert_error_sent(500, fn -> get(proxied_conn(), "/raise") end)
      assert body == "Internal Server Error"
      assert {"content-type", "text/plain; charset=utf-8"} in headers

      {500, _headers, body} = assert_error_sent(500, fn -> get(proxied_conn(), "/throw") end)
      assert body == "Internal Server Error"
    end

    test "get a plain 404 with no route list for an unknown path" do
      # Phoenix does not raise again for a missing route, so read the response that was sent.
      {404, _headers, body} = proxied_conn() |> get("/unknown") |> Plug.Test.sent_resp()
      assert body == "Not Found"
    end

    test "keep a response that was sent before the error" do
      {200, _headers, body} = assert_error_sent(200, fn -> get(proxied_conn(), "/send-then-raise") end)
      assert body == "sent"
    end

    test "get a plain compile-error page" do
      conn = get(proxied_conn(), "/compile-error")
      assert conn.status == 500
      assert conn.resp_body == "Internal Server Error"
      assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
    end

    test "keep a 500 response that is not HTML" do
      conn = get(proxied_conn(), "/json-error")
      assert conn.resp_body == ~s({"error":"json"})
    end
  end

  describe "local requests" do
    test "reach the local-only paths" do
      for path <- ["/tidewave/mcp", "/dev/dashboard", "/phoenix/live_reload/frame"] do
        assert get(build_conn(), path).resp_body == "ok", path
      end
    end

    test "pass the router plug" do
      assert get(build_conn(), "/tools/page").resp_body == "ok"
    end

    test "reach the Plug.Debugger action path" do
      # Plug.Debugger gets the request and refuses the unsigned handler.
      assert_raise RuntimeError, ~r/could not run Plug.Debugger action/, fn ->
        post(build_conn(), "/__plug__/debugger/action", %{"encoded_handler" => "x"})
      end
    end

    test "get the debugger page for an error" do
      conn = put_req_header(build_conn(), "accept", "text/html")
      {500, _headers, body} = assert_error_sent(500, fn -> get(conn, "/raise") end)
      assert body =~ "raised in the test router"
      assert body =~ "<html"
    end

    test "get the compile-error page" do
      conn = get(build_conn(), "/compile-error")
      assert conn.status == 500
      assert conn.resp_body =~ "compiler output"
    end
  end

  describe "proxied?/1" do
    test "reads a conn or a header list" do
      assert LocalDevTools.proxied?(proxied_conn())
      refute LocalDevTools.proxied?(build_conn())
      assert LocalDevTools.proxied?([{"x-forwarded-for", "203.0.113.7"}])
      refute LocalDevTools.proxied?([{"x-request-id", "abc"}])
    end
  end

  describe "on_mount/4" do
    defp socket(connect_info) do
      %Phoenix.LiveView.Socket{private: %{connect_info: connect_info, lifecycle: %Phoenix.LiveView.Lifecycle{}}}
    end

    test "halts and redirects a proxied connection" do
      socket = socket(%{x_headers: [{"x-forwarded-for", "203.0.113.7"}]})
      assert {:halt, %{redirected: {:redirect, %{to: "/"}}}} = LocalDevTools.on_mount(:local_only, %{}, %{}, socket)
    end

    test "continues a local connection" do
      assert {:cont, _socket} = LocalDevTools.on_mount(:local_only, %{}, %{}, socket(%{x_headers: [{"x-request-id", "abc"}]}))
      assert {:cont, _socket} = LocalDevTools.on_mount(:local_only, %{}, %{}, socket(%{}))
    end
  end
end
