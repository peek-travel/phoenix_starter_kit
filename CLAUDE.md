# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About This Repo

This is a **starter kit template** for building Elixir/Phoenix apps that integrate with Peek Pro. It is used as a GitHub template — once a new repo is created from it, run `bin/setup` to rename the project and configure it for your use case. The demo context (`lib/phoenix_starter_kit/demo/`, `lib/phoenix_starter_kit_web/live/demo/`) exists as a reference example and is typically removed after setup.

## Common Commands

- **Full check (format + lint + tests):** `./bin/check` — run this after every task
- **Start dev server:** `bin/server` (runs `iex -S mix phx.server`)
- **Start with Cloudflare tunnel:** `bin/dev`
- **Run all tests with coverage:** `mix coveralls.lcov`
- **Run a single test file:** `mix test test/path/to_test.exs`
- **Run a single test by line:** `mix test test/path/to_test.exs:42`
- **Format code:** `mix format`
- **Lint:** `mix credo`
- **Setup (deps + db + assets):** `mix setup`
- **Reset database:** `mix ecto.reset`
- **Sync app manifest with registry:** `bin/sync`

## Test Coverage

100% test coverage is required and enforced in CI. After making changes, always run `./bin/check` to verify formatting, linting, and full test coverage pass.

## Architecture

**Phoenix 1.8 + LiveView + Ecto + PostgreSQL.** Bandit HTTP server. TailwindCSS v4 + DaisyUI frontend.

### Contexts

- **Partners** (`lib/phoenix_starter_kit/partners.ex`) — core context managing partners, partner users, session tokens, and partner-user connections. Partners are multi-tenant, scoped by `platform` (`:peek`, `:acme`, `:cng`).
- **Platforms** (`lib/phoenix_starter_kit/platforms/`) — platform-specific logic abstracted behind `PeekPro`, `ACME`, `CNG` modules.
- **Health** (`lib/phoenix_starter_kit/health.ex`) — health check and usage metrics.
- **Demo** (`lib/phoenix_starter_kit/demo.ex`) — example CRUD context for reference.

### Base Schema

All schemas use `PhoenixStarterKit.Schema` which sets UUID binary primary keys, binary foreign keys, and `utc_datetime_usec` timestamps.

### Authentication

Two auth flows coexist:
1. **Partner User (session-based)** — email-only login (no passwords), session tokens stored in DB with 24-hour TTL. See `PartnerUserAuth` module.
2. **Peek Pro (JWT-based)** — JWT verified by `PeekAppSDK`, delivered via iframe POST, converted to a Phoenix signed auth token for LiveView sessions.

### Web Layer

Key pipelines in the router:
- `:browser` — standard Phoenix browser with partner user auth
- `:webhook` — JSON endpoints for Peek registry/booking webhooks
- `:widget_api` — JSON endpoints with CORS for client-side widget
- `:peek_pro_embed` — iframe embedding flow for Peek Pro settings

### Assets

esbuild bundles two entry points: `app.js` (main app) and `widget_extension.ts` (embeddable widget script). Tailwind v4 with DaisyUI and Heroicons plugins.

## Code Style

- Formatter line length: **140 characters**
- Formatter plugins: `Phoenix.LiveView.HTMLFormatter`
- Compile with `--warnings-as-errors` in CI
- Mocking: uses `Mimic` (not `Mox`)
- Test fixtures in `test/support/fixtures/`
