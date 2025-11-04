defmodule PhoenixStarterKitWeb.Endpoint do
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :phoenix_starter_kit

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_phoenix_starter_kit_key",
    signing_salt: "W8a8btWf",
    same_site: "None",
    max_age: 2_592_000,
    secure: true
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :phoenix_starter_kit,
    gzip: not code_reloading?,
    only: PhoenixStarterKitWeb.static_paths(),
    headers:
      if(code_reloading?,
        do: [
          {"access-control-allow-origin", "*"},
          {"access-control-allow-methods", "GET, OPTIONS"},
          {"access-control-allow-headers", "content-type"},
          {"cache-control", "no-store, no-cache, must-revalidate, max-age=0"}
        ],
        else: [
          {"access-control-allow-origin", "*"},
          {"access-control-allow-methods", "GET, OPTIONS"},
          {"access-control-allow-headers", "content-type"}
        ]
      )

  if Code.ensure_loaded?(Tidewave) do
    plug Tidewave
  end

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :phoenix_starter_kit
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Sentry.PlugContext
  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug PhoenixStarterKitWeb.Router
end
