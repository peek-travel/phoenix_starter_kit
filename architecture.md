# Phoenix Starter Kit Architecture

This document describes the architecture and design decisions of the Phoenix Starter Kit for Peek Pro Apps.

## Overview

The Phoenix Starter Kit is a template for building Peek Pro applications using Elixir and Phoenix. It provides the foundational structure for apps that integrate with the Peek Pro platform, including authentication, webhooks, and partner management.

## Technology Stack

- **Language**: Elixir 1.14+
- **Framework**: Phoenix 1.8+
- **Database**: PostgreSQL with Ecto
- **Frontend**: Phoenix LiveView with TailwindCSS
- **Authentication**: PeekAppSDK + custom partner user auth
- **Deployment**: Platform-agnostic

## Application Structure

### Contexts

The application follows Phoenix's context pattern for organizing business logic:

#### Partners Context (`lib/phoenix_starter_kit/partners.ex`)

Manages all partner-related functionality:
- **Partner**: Represents a Peek Pro partner who has installed the app
- **PartnerUser**: Users who can log in on behalf of a partner
- **PartnerUserConnection**: Many-to-many relationship between partners and users
- **PeekProInstallation**: Embedded schema tracking installation status

Key responsibilities:
- Partner creation and management
- Partner user authentication (email-based, no passwords)
- Installation status tracking
- Partner-user relationship management

#### Demo Context (`lib/phoenix_starter_kit/demo.ex`)

Example CRUD functionality demonstrating:
- LiveView patterns
- Database operations
- Form handling
- Testing patterns

This is meant to be replaced with your app's specific business logic.

#### Health Context (`lib/phoenix_starter_kit/health.ex`)

Provides health check and usage metrics:
- System health status (RAG: Red/Amber/Green)
- Active partner counts
- Installation metrics
- Custom metrics (extensible)

### Web Layer

#### Authentication Flows

1. **Partner User Authentication** (`lib/phoenix_starter_kit_web/partner_user_auth.ex`)
   - Email-based authentication
   - Session management
   - No passwords required
   - Used for standalone access

2. **Peek Pro Embedded Authentication** (`PeekAppSDK.Plugs.PeekAuth`)
   - JWT-based authentication from Peek Pro
   - Validates tokens from the Peek Pro platform
   - Handles iframe embedding
   - Safari compatibility workarounds

#### Pipelines

- **`:browser`**: Standard Phoenix browser pipeline with partner user auth
- **`:api`**: JSON API endpoints
- **`:peek_pro_api`**: Webhook endpoints from Peek Pro (authenticated via SDK)
- **`:peek_pro_embed`**: Embedded iframe endpoints (authenticated via Peek Pro)
- **`:widget_api`**: Client-side widget endpoints (optional, with CORS)

#### Key Routes

- `/` - Landing page
- `/settings` - Partner user settings (requires auth)
- `/peek-pro/settings` - Embedded settings page (Peek Pro iframe)
- `/peek-pro/api/on-installation-status-change` - Installation webhook
- `/peek-pro/api/on-booking-change` - Booking change webhook
- `/health` - Health check endpoint
- `/demo/*` - Demo CRUD functionality

### Data Model

```
┌─────────────────┐
│    Partner      │
├─────────────────┤
│ id (UUID)       │
│ peek_install_id │◄──── Unique identifier from Registry
│ platform        │◄──── Enum: peek | acme | cng
│ is_test         │
│ peek_pro_inst...│◄──── Embedded: installation status, timestamps
└─────────────────┘
         │
         │ many-to-many
         ▼
┌─────────────────────────┐
│ PartnerUserConnection   │
├─────────────────────────┤
│ partner_id              │
│ partner_user_id         │
└─────────────────────────┘
         │
         ▼
┌─────────────────┐
│  PartnerUser    │
├─────────────────┤
│ id (UUID)       │
│ email           │◄──── Primary identifier (no password)
│ session_token   │
└─────────────────┘
```

### Frontend Architecture

#### LiveView Components

- **Core Components** (`lib/phoenix_starter_kit_web/components/core_components.ex`)
  - Reusable UI components
  - Form inputs, buttons, modals, tables
  - Flash messages, headers

- **Legacy Peek Components** (`lib/phoenix_starter_kit_web/components/legacy_peek_components.ex`)
  - Peek-specific UI patterns
  - Maintained for compatibility

#### Widget Extension (Optional)

- TypeScript-based widget (`assets/js/widget_extension.ts`)
- Can be embedded in Peek Pro's frontend
- Communicates with backend via authenticated API
- Requires `CLIENT_SECRET_TOKEN` configuration

### Security

#### Authentication Layers

1. **Partner User Sessions**: Cookie-based sessions for standalone access
2. **Peek Pro JWT**: Token-based auth for embedded contexts
3. **Client Secret**: Optional token for widget-to-backend communication
4. **CSRF Protection**: Enabled for all form submissions

#### Data Protection

- UUIDs for all primary keys (prevents enumeration)
- Session tokens stored securely
- No password storage (email-based auth only)
- Proper indexing for performance and security

### External Integrations

#### Peek App SDK

The app integrates with Peek Pro via the `peek_app_sdk` package:
- Installation lifecycle management
- JWT authentication
- Webhook signature verification
- Partner data synchronization

Configuration required:
- `PEEK_APP_ID`: Your app's unique identifier
- `PEEK_APP_SECRET`: Shared secret for webhooks
- `PEEK_API_KEY`: Gateway key for API access (optional)

#### Webhooks

The app receives webhooks from Peek Pro:

1. **Installation Status Change**
   - Triggered when app is installed/uninstalled
   - Updates partner installation status
   - Creates/updates partner records

2. **Booking Change** (Example)
   - Triggered on booking events
   - Demonstrates event handling pattern
   - Extend for your app's needs

### Development Workflow

#### Local Development

1. **Database**: PostgreSQL running locally
2. **Tunnel**: Cloudflare tunnel via `bin/dev` for Peek Pro integration
3. **Hot Reload**: Phoenix LiveReload for rapid development
4. **Testing**: Full test suite with 100% coverage requirement

#### Scripts

- `bin/server`: Start Phoenix with IEx
- `bin/dev`: Start Cloudflare tunnel for local development
- `bin/check`: Run tests and code quality checks
- `bin/rename`: Rename the entire project
- `bin/sync`: Sync app config with Peek Pro registry
- `bin/enable-flyio`: Enable Fly.io deployment support (optional)


### Configuration Management

- **Development**: `.env` file (not committed)
- **Test**: `.env.test` file
- **Production**: Environment variables via your favorite secret manager

### Testing Strategy

- **Unit Tests**: Context functions, business logic
- **Controller Tests**: HTTP endpoints, webhooks
- **LiveView Tests**: Interactive components
- **Integration Tests**: End-to-end flows
- **Coverage**: 100% required (configurable in CI)

### Code Quality

- **Formatter**: Elixir formatter with 140 character line length
- **Linter**: Credo for code consistency
- **Type Specs**: Encouraged but not required
- **Documentation**: Moduledocs and function docs

## Design Decisions

### Why Email-Only Authentication?

Partner users authenticate via email only (no passwords) because:
1. Simplifies onboarding for partners
2. Reduces security surface area
3. Partners primarily access via Peek Pro (JWT auth)
4. Standalone access is secondary use case

### Why Embedded Schemas?

`PeekProInstallation` is embedded rather than a separate table because:
1. 1:1 relationship with Partner
2. Installation data is tightly coupled to partner
3. Simplifies queries and reduces joins
4. Installation data is not queried independently

### Why UUIDs?

All tables use UUID primary keys because:
1. Prevents ID enumeration attacks
2. Enables distributed ID generation
3. Better for public APIs
4. Standard practice for Peek Pro apps

## Extending the Starter Kit

### Adding New Features

1. Create a new context in `lib/phoenix_starter_kit/`
2. Add schemas in the context module
3. Create migrations in `priv/repo/migrations/`
4. Add controllers/LiveViews in `lib/phoenix_starter_kit_web/`
5. Update router with new routes
6. Write tests in `test/`
7. Update this architecture doc

### Integrating with Peek Pro API

If your app needs to call Peek Pro APIs:
1. Obtain a gateway key (contact Peek support)
2. Set `PEEK_API_KEY` environment variable
3. Use the PeekAppSDK client for authenticated requests
4. Handle rate limiting and errors appropriately

### Adding Webhooks

To handle additional Peek Pro events:
1. Add new function in `WebhookController`
2. Register webhook in `app.json` extendables
3. Implement event handling logic
4. Add tests for webhook processing

## Performance Considerations

- Database queries use proper indexing
- LiveView reduces full page reloads
- Static assets compiled and minified for production
- Connection pooling configured for database
- Cloudflare tunnel provides CDN benefits in dev

## Monitoring and Observability

- Health check endpoint for uptime monitoring
- Usage metrics for partner analytics
- Sentry integration for error tracking (configured but requires setup)
- Phoenix LiveDashboard for development insights

## Future Enhancements

Consider adding:
- Background job processing (Oban)
- Caching layer (Cachex, Redis)
- Rate limiting (Hammer)
- API versioning
- GraphQL endpoint
- Multi-tenancy improvements
- Audit logging
