defmodule PhoenixStarterKit.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Add Sentry logger handler to capture crashed process exceptions
    :logger.add_handler(:sentry_handler, Sentry.LoggerHandler, %{
      config: %{metadata: [:file, :line]}
    })

    children = [
      PhoenixStarterKitWeb.Telemetry,
      PhoenixStarterKit.Repo,
      {DNSCluster, query: Application.get_env(:phoenix_starter_kit, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PhoenixStarterKit.PubSub},
      # Start a worker by calling: PhoenixStarterKit.Worker.start_link(arg)
      # {PhoenixStarterKit.Worker, arg},
      # Start to serve requests, typically the last entry
      PhoenixStarterKitWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhoenixStarterKit.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhoenixStarterKitWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
