defmodule PhoenixStarterKitWeb.Router do
  use PhoenixStarterKitWeb, :router

  import PeekAppSDK.Plugs.ClientAuth
  import PeekAppSDK.Plugs.PeekAuth
  import PhoenixStarterKitWeb.PartnerUserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PhoenixStarterKitWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_partner_user
    plug :allow_peek_iframe
    plug PhoenixStarterKitWeb.Plugs.SetCurrentPartner
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :peek_pro_api do
    plug :accepts, ["json"]
    plug :set_peek_install_id
    plug :allow_peek_iframe
  end

  pipeline :widget_api do
    plug :accepts, ["json"]
    plug :set_peek_install_id_from_client
    plug PhoenixStarterKitWeb.Plugs.CORS
  end

  pipeline :peek_pro_embed do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :set_peek_install_id
    plug :allow_peek_iframe
    plug PhoenixStarterKitWeb.Plugs.SetCurrentPartner
  end

  scope "/", PhoenixStarterKitWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  ## Authentication routes
  scope "/", PhoenixStarterKitWeb do
    pipe_through [:browser, :require_authenticated_partner_user]

    live_session :require_authenticated_partner_user,
      on_mount: [{PhoenixStarterKitWeb.PartnerUserAuth, :ensure_authenticated}] do
      live "/settings", SettingsLive, :index
    end
  end

  # Widget API endpoints (optional)
  # If your app includes a frontend widget that needs to communicate with this backend,
  # use the :widget_api pipeline which includes CORS support and client authentication.
  #
  # To enable widget authentication:
  # 1. Uncomment CLIENT_SECRET_TOKEN in .env.example and set a secure value
  # 2. Add the client_secret_token to your app.json extendable configuration
  # 3. See docs/widget-integration.md for full setup instructions (create this doc as needed)
  scope "/widget", PhoenixStarterKitWeb.Widget do
    pipe_through [:widget_api]

    get "/your_end_point", WidgetController, :your_end_point
    options "/your_end_point", WidgetController, :options
  end

  scope "/peek-pro/api", PhoenixStarterKitWeb.PeekPro do
    pipe_through [:peek_pro_api]

    post "/on-installation-status-change", WebhookController, :on_installation_status_change
    post "/on-booking-change", WebhookController, :on_booking_change
  end

  scope "/peek-pro/settings", PhoenixStarterKitWeb.PeekPro do
    pipe_through [:peek_pro_embed]

    post "/", EmbedsController, :landing
  end

  scope "/health", PhoenixStarterKitWeb do
    pipe_through :api

    post "/", HealthController, :index
  end

  scope "/demo", PhoenixStarterKitWeb.Demo, as: :demo do
    pipe_through :browser

    live_session :demo,
      layout: {PhoenixStarterKitWeb.Layouts, :demo},
      on_mount: [{PhoenixStarterKitWeb.PartnerUserAuth, :mount_current_partner_user}] do
      live "/demo_records", DemoRecordLive.Index, :index
      live "/demo_records/new", DemoRecordLive.Form, :new
      live "/demo_records/:id", DemoRecordLive.Show, :show
      live "/demo_records/:id/edit", DemoRecordLive.Form, :edit

      live "/components", DemoComponentsLive, :index
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:phoenix_starter_kit, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PhoenixStarterKitWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
