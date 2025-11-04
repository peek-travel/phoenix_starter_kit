# Phoenix Starter Kit for Peek Pro Apps

This starter kit provides the essential components for building a Peek Pro app using Elixir and Phoenix. It includes the necessary infrastructure for authentication, embedding within Peek Pro, handling webhooks, and managing partner installations.

## Overview

The Phoenix Starter Kit is designed to help developers quickly build Peek Pro apps by providing the boilerplate code needed for common functionality. The key features include:

1. **PeekAppSDK Integration**: Ready-to-use integration with the Peek App SDK for authentication and embedding
2. **Partner Management**: Models and logic for managing partners and partner users
3. **Webhook Handling**: Controllers for processing Peek Pro webhooks
4. **Health Check**: Endpoints for monitoring the application's health

## Core Components

### Authentication and Authorization

The application implements two authentication flows:

1. **Partner User Authentication**: Uses a simplified authentication system to manage partner users based on their email.
2. **PeekPro Authentication**: Integrates with PeekAppSDK to support embedding within the Peek Pro interface, allowing seamless access for Peek Pro users.

### Data Model

The core data model consists of several key entities:

- **Partner**: Represents a Peek Pro partner who has installed the app. Contains information about the Peek Pro installation.
- **PartnerUser**: Represents a user who can log in to the system on behalf of a partner.
- **PartnerUserConnection**: Represents the many-to-many relationship between partners and partner users.

The Partner schema includes an embedded schema for:

- **PeekProInstallation**: Tracks the status and details of the Peek Pro app installation

### Web Interface

The web interface is designed to be embedded within the Peek Pro application using iframes, providing a seamless experience for partners.

### API Endpoints

The application exposes several API endpoints:

1. **Peek Pro API Endpoints**:

   - `/peek-pro/api/on-installation-status-change`: Handles app installation events
   - `/peek-pro/api/on-booking-change`: Processes booking change notifications from Peek Pro

2. **Health Check Endpoint**:
   - `/health`: Provides health status information about the application

## Technical Architecture

### Application Structure

The application follows a standard Phoenix structure with a single context:

- **Partners**: Handles partner data, partner users, and authentication

### Database

The application uses PostgreSQL with Ecto for database access. Key features include:

- UUID primary keys for all tables
- Embedded schemas for complex nested data
- Proper indexing for performance

### Security Considerations

Security is a priority in the application design:

- Session tokens are stored securely
- All endpoints are properly authenticated
- CSRF protection is enabled for web forms
- No passwords are stored or required for partner users

## Getting Started

To start using this starter kit:

- [Create a new repo from this template](https://github.com/new?owner=peek-travel&template_name=phoenix_starter_kit&template_owner=peek-travel), run mix deps.get and bin/check and ensure things are kosher.
- Run `bin/rename "Your Project Name"`
- Make your .env file; `cp .env.example .env`
- Run database migrations with `mix ecto.setup`
- Start the Phoenix server with `bin/server`; ensure you can see things, etc.
- Run `bin/dev` to set up a secure Cloudflare tunnel for development (see Development Tunnel section below)
- Put your tunnel URL as the base_url inside app.json (e.g., `https://your-app-name-dev.peeklabs.com`)
- **Contact Peek App Support** to obtain:
  - A test account for Peek Pro
  - A publisher API key to push your app to the sandbox environment
  - A gateway key if you need to communicate with the Peek Pro API
- Experimental: `bin/sync app.json` will guide you through creating/updating
  an app in the registry. You will need to update the env file accordingly with
  your publisher key and the URL of the registry you wish to interact with.

## Development Tunnel

Instead of using ngrok, use `bin/dev` to create a secure Cloudflare tunnel for development:

```bash
bin/dev
```

Your app will be available at `https://phoenix-starter-kit-dev.peeklabs.com` (or whatever you renamed your app to).

**What it does:**

- Automatically installs `cloudflared` if needed
- Creates a Cloudflare tunnel with SSL and WebSocket support
- Sets up DNS routing to `{your-app-name}-dev.peeklabs.com`
- Reuses existing tunnels when possible, recreates them when switching machines/developers

**Multiple projects:** Each app gets its own tunnel config, so you can run multiple projects simultaneously on different ports.

## An app w/ Multiple Envs

Your `.env` file will contain the app id and secret for the app you are
currently running. Currently the best way to deal with multiple envs is to have
multiple apps in the registry. You can then create `app-local.json` v
`app-prod.json` etc. The gotcha is you have to make sure you have the correct id
and secret in your .env file.

## Customization

To customize the starter kit for your specific Peek Pro app:

1. Add your own controllers, live views, and templates
2. Extend the Partner schema with additional fields as needed
3. Implement your specific business logic in the appropriate contexts
4. Update the router with additional routes for your application

## Available Scripts

The `bin/` directory contains several useful scripts:

- **`bin/dev`**: Sets up and runs a Cloudflare tunnel for development. Automatically creates `{app-name}-dev.peeklabs.com` tunnel.
- **`bin/server`**: Starts the Phoenix server with IEx for development.
- **`bin/rename`**: Renames the entire project from "Phoenix Starter Kit" to your app name.
- **`bin/check`**: Runs tests and code quality checks.
- **`bin/sync`**: Syncs your app configuration with the Peek Pro registry.
- **`bin/enable-flyio`**: Enables Fly.io deployment support (optional, see deployment section below).

## Deployment

The starter kit is ready for deployment to production environments. It includes:

- Configuration via environment variables
- Support for database migrations during deployment
- Health check endpoints for monitoring

This application can be deployed to any platform that supports Phoenix applications, such as:

- Fly.io
- Render
- Heroku
- Gigalixir
- AWS/GCP/Azure with Docker
- Your own infrastructure

### Optional: Deploying to Fly.io

If you want to deploy to [Fly.io](https://fly.io/), first run the setup script to add Fly.io-specific files:

```bash
bin/enable-flyio
```

This will create:

- `bin/proxy_prod` - Script to connect to production database locally
- `bin/shell_prod` - Script to open IEx shell on production

**Prerequisites:**

1. Install the Fly CLI: <https://fly.io/docs/flyctl/install/>
2. **Contact Peek App Support** to get access to the Peek organization on Fly.io (if deploying Peek Pro apps)

**Deployment Steps:**

1. Run `fly launch` to create your app and generate `fly.toml`
2. Update `bin/proxy_prod` with your database app name
3. Update `bin/shell_prod` with your app name
4. Set your environment variables:

   ```bash
   fly secrets set PEEK_APP_ID=your-app-id
   fly secrets set PEEK_APP_SECRET=your-app-secret
   fly secrets set PEEK_API_KEY=your-gateway-key
   # Add other required secrets
   ```

5. Deploy: `fly deploy`

**Useful Commands:**

- `bin/proxy_prod` - Connect to your production database locally (via TablePlus or similar)
- `bin/shell_prod` - Open an IEx shell connected to your production app

## Troubleshooting

### Changes on peek_app_sdk are not showing up

If you have made changes to the peek_app_sdk and they are not showing up here, you
likely need to "unlock" the dep and then re-fetch it.

```bash
mix deps.unlock peek_app_sdk
rm -rf deps/peek_app_sdk _build
mix deps.get
```
