defmodule PhoenixStarterKit.Repo do
  use Ecto.Repo,
    otp_app: :phoenix_starter_kit,
    adapter: Ecto.Adapters.Postgres
end
