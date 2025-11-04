import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :phoenix_starter_kit, PhoenixStarterKit.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "phoenix_starter_kit_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :phoenix_starter_kit, PhoenixStarterKitWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "u185vjsL+YPVw49/uA/jUZQaezuzARYZNwIxi1I79KSnK8/gOHdsdy789mNSjnJj",
  server: false

# In test we don't send emails
config :phoenix_starter_kit, PhoenixStarterKit.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_starter_kit, :embedded_app_url, nil

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Configure Peek App SDK for tests
config :peek_app_sdk,
  peek_api_key: "test-app-key",
  peek_app_id: "test-app-id",
  peek_app_secret: "test-app-secret"

# Tesla adapter configuration removed - using mimic for mocking instead
