defmodule PhoenixStarterKit.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_starter_kit,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        "coveralls.json": :test,
        "coveralls.html": :test,
        "coveralls.lcov": :test,
        "coveralls.detail": :test,
        "coveralls.github": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {PhoenixStarterKit.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:bandit, "~> 1.5"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:postgrex, ">= 0.0.0"},
      {:phoenix, "~> 1.8"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:sentry, "~> 11.0.1"},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons, github: "tailwindlabs/heroicons", tag: "v2.1.1", sparse: "optimized", app: false, compile: false, depth: 1},
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.13"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1"},
      {:dotenvy, "~> 1.0"},
      {:peek_app_sdk, git: "https://github.com/peek-travel/peek_app_sdk.git", branch: "feature/new-theme", override: true},
      {:excoveralls, "~> 0.16"},
      {:mimic, "~> 2.0", only: :test},
      {:tidewave, "~> 0.4", only: :dev},
      {:tzdata, "~> 1.1"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind phoenix_starter_kit", "esbuild phoenix_starter_kit", "esbuild widget_extension"],
      "assets.deploy": [
        "tailwind phoenix_starter_kit --minify",
        "esbuild phoenix_starter_kit --minify",
        "esbuild widget_extension --minify",
        "phx.digest",
        "sentry.package_source_code"
      ]
    ]
  end
end
