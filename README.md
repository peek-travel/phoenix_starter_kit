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

1. [Create a new repo from this template](https://github.com/new?owner=peek-travel&template_name=phoenix_starter_kit&template_owner=peek-travel)
2. Clone your new repository
3. Run `bin/setup` and follow the interactive prompts:
   - Enter your application name (e.g., "My Awesome App")
   - Select your deployment platform (Fly.io or other)
4. Make your .env file: `cp .env.example .env`
5. Run database migrations with `mix ecto.setup`
6. Start the Phoenix server with `bin/server`
7. Run [`ngrok`](#ngrok-method) or [`bin/dev`](#bindev-method) to set up a secure tunnel for development (see Development Tunnel section below)
8. Put your tunnel URL as the base_url inside app.json (e.g., `https://your-app-name-dev.peeklabs.com`)
9. **Contact Peek App Support** to obtain:
   - A test account for Peek Pro
   - A publisher API key to push your app to the sandbox environment
   - A gateway key if you need to communicate with the Peek Pro API
10. Experimental: `bin/sync app.json` will guide you through creating/updating an app in the registry

The setup script creates a `.phoenix_starter_kit_version` file containing the template commit hash. This enables future auto-update capabilities to pull in template improvements.

## Development Tunnel

### Local Development

#### ngrok Method

The easiest and most direct way to publish an app without a formal deployment cycle is with `ngrok`.
If you do not have `ngrok` installed on your machine, you can install it with `brew install ngrok`.
You will need to create an `ngrok` account if you do not have one already. You can link it with
either your GitHub or your Gmail account. The free-tier is suitable for the purposes of developing apps.

Once it is installed, you can run `ngrok config add-authtoken <token>`, where `<token>` is the token
provided when you created the `ngrok` account.

You will also need to copy the URL provided by `ngrok` and paste it as the `PHX_HOST` value in the `.env`
file. Do **not** include the protocol (eg. `https`) in the `PHX_HOST` value. `PHX_PORT` should be set to
`433` and `PHX_SCHEME` should be set to `https`. Your `.env` file will have a section that looks like this
when completed correctly:

```
PHX_HOST="extravagant-salted-cornstalk.ngrok-free.dev"
PHX_PORT="443"
PHX_SCHEME="https"
```

Note: your `PHX_HOST` **will** be different than the one listed above.

To run your app with `ngrok` after you have set it up, open two terminals. In the first, you should run:

```bash
bin/server
```

This will start the Phoenix application and should produce output like the following:

```bash
> bin/server
Erlang/OTP 28 [erts-16.0.1] [source] [64-bit] [smp:14:14] [ds:14:14:10] [async-threads:1] [jit]

[info] Running TestPeekAppWeb.Endpoint with Bandit 1.8.0 at 0.0.0.0:4000 (http)
[info] Access TestPeekAppWeb.Endpoint at https://extravagant-salted-cornstalk.ngrok-free.dev
Interactive Elixir (1.18.4) - press Ctrl+C to exit (type h() ENTER for help)
[watch] build finished, watching for changes...
[watch] build finished, watching for changes...
/*! 🌼 daisyUI 5.0.8 */
≈ tailwindcss v4.0.9
```

**Note**: You can navigate to the `0.0.0.0:4000` endpoint in your browser and see the scaffolded
app. On Chromium-based browsers, the `0.0.0.0:4000` endpoint will work. However, it will **not**
work on Webkit-based browsers (like Safari). Instead you will need to use `localhost:4000`.

In the other terminal, you should run:

```bash
ngrok http 4000
```

This will start `ngrok` and forward from the 4000 port on your local machine. The output should look like:

```
ngrok

🧱 Block threats before they reach your services with new WAF actions → https://ngrok.com/r/waf

Session Status                online
Account                       your.email@peek.com (Plan: Free)
Version                       3.34.0
Region                        United States (us)
Web Interface                 http://127.0.0.1:4040
Forwarding                    https://extravagant-salted-cornstalk.ngrok-free.dev -> http://localhost:4000

Connections                   ttl     opn     rt1     rt5     p50     p90
                              0       0       0.00    0.00    0.00    0.00
```

When both of these are running, you should be able to navigate to your version of the
`https://extravagant-salted-cornstalk.ngrok-free.dev` URL and see your app. This URL can be
accessed across systems.

**Note**: If you get an SSL error when accessing the URL, your WiFi router might be configured in such a way
that `ngrok` is blocked. On your cell phone, turn WiFi off and turn your cellular connection on and try accessing
the URL. If this works, then it is an issue with your Internet hardware rather than `ngrok` or application
configuration.

#### `bin/dev` Method

**Important**: To use this method, you need to contact Peek to create your publisher account. You will be provided
with values to use in the `.env` file associated with your app:

```
PEEK_APP_REGISTRY_URL=<provided_app_registry_url>
PEEK_APP_REGISTRY_AUTH_TOKEN=<provided_app_registry_auth_token>
```

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

## `bin/sync app.json` (Experimental)

Running `bin/sync app.json` requires `PEEK_APP_REGISTRY_URL` and `PEEK_APP_REGISTRY_AUTH_TOKEN` values.
These values are provided by Peek and must be configured in `.env` before running `bin/sync app.json`.

When running this command, you will be given a secret token.
Enter this token as the value to the `PEEK_APP_SECRET` variable in the `.env` file.
The other important keys and values in `.env` are as follows (note that `APP_API_KEY`
should be any value; `not-used` is an acceptable value):

```
PEEK_APP_ID="{{the `id` value in app.json after running `bin/sync app.json`}}"
EMBEDDED_APP_URL="{{the `app_url` value in app.json after running `bin/sync app.json`}}"
PEEK_API_KEY="not-used"
PEEK_APP_BASE_URL="{{a target url for an environment; ask Peek for further clarification}}"
```

**Note**: The `PEEK_APP_BASE_URL` should be configured for the target environment.
For example, if you point `bin/sync` to stage, you need to set a stage app registry endpoint
as the value so you can communicate with the SDK.

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

- **`bin/setup`**: Interactive setup wizard that renames the project, configures deployment platform, and creates version tracking file.
- **`bin/dev`**: Sets up and runs a Cloudflare tunnel for development. Automatically creates `{app-name}-dev.peeklabs.com` tunnel.
- **`bin/server`**: Starts the Phoenix server with IEx for development.
- **`bin/check`**: Runs tests and code quality checks.
- **`bin/sync`**: Syncs your app configuration with the Peek Pro registry.

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

### Deploying to Fly.io

If you selected Fly.io during `bin/setup`, the following scripts were automatically added:

- `bin/dev` - Cloudflare tunnel for development
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

### Generators need required partner_ids on models (`phx.gen.live`)

The routes you put the generations into have auth. This means you have to log in
to use them. The tests do not log in. All you have to do is add
`register_and_log_in_partner_user` to the `setup` section of the tests. For example:

```elixir
  describe "SettingsLive" do
    setup [:register_and_log_in_partner_user]

    test "It works!"
    end
  end
```

Generated schemas might not include `partner_id` in the cast section of
changeset. You have to add it manually if you are seeing changeset errors.

You have to always set a partner id when creating records both in fixtures and
in your actual code (which will be the logged in partner)

For fixtures: 
At the top of the fixture function:

```elixir
    attrs = Map.put_new_lazy(attrs, :partner_id, fn -> PhoenixStarterKit.PartnersFixtures.partner_fixture().id end)
```

This will fix everything using the factories, but there are also test that test
the context functions, so you have to patch those failures as well.

Finally, in the actual code you have to make sure you are setting the partner_id
when creating records. For example, in the `save_record` function of the
`RecordLive.FormComponent` you would add the following:
```elixir
  defp save_record(socket, :new, record_params) do
    record_params = Map.put(record_params, "partner_id", socket.assigns.current_partner_user.partner.id)
```