# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :phoenix_starter_kit,
  ecto_repos: [PhoenixStarterKit.Repo],
  generators: [timestamp_type: :utc_datetime_usec]

config :phoenix_starter_kit, :generators, binary_id: true

config :phoenix_starter_kit, PhoenixStarterKit.Repo, migration_timestamps: [type: :utc_datetime_usec]

# Configures the endpoint
config :phoenix_starter_kit, PhoenixStarterKitWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PhoenixStarterKitWeb.ErrorHTML, json: PhoenixStarterKitWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PhoenixStarterKit.PubSub,
  live_view: [signing_salt: "E2ajFMP6"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  phoenix_starter_kit: [
    args: ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ],
  widget_extension: [
    args: ~w(js/widget_extension.ts --target=es2017 --outfile=../priv/static/assets/widget_extension.js),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.0.9",
  phoenix_starter_kit: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :sentry, client: PhoenixStarterKit.SentryFinchClient

# Configure timezone database
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
