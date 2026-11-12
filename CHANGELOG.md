# Changelog

## Unreleased

### Iframe login, framing, logs and Sentry

- **Breaking:** the Peek Pro landing page now redirects to `/settings?login_token=<token>&locale=<locale>`, not to `/settings?auth_token=<token>`.
  - The login token works one time, for 60 seconds. `/settings` exchanges it for an embed session token: a row in `partner_users_tokens`, valid for 24 hours.
  - Logout and app uninstall delete the embed session tokens. The open LiveViews then redirect to `/`.
  - A request with a login token that is used or expired shows the "Session Expired" page. In an iframe, that page reloads the Peek Pro parent page.
  - After the update, the old `auth_token` links stop working. Users open the app from Peek Pro again.
  - Update your code: `fetch_partner_user_from_auth_token` is now `fetch_partner_user_from_login_token`. `live_session_data/1` returns `"embed_session_token"`, not `"auth_token"`. `Partners.get_partner_user/1` is removed.
- **Breaking:** the new plug `PhoenixStarterKitWeb.Plugs.ContentSecurityPolicy` replaces `allow_peek_iframe` in the router. It sets `base-uri 'self'; frame-ancestors 'self' https://*.peek.com https://*.peeklabs.com`.
  - An app that runs in a frame on other hosts must set them in the `FRAME_ANCESTORS` env var (space-separated) or in `config :phoenix_starter_kit, :frame_ancestors`.
- `config :phoenix, :filter_parameters` is now `["password", "token", "peek-auth"]`. The logs do not show the values of params whose names contain these words.
- `Sentry.PlugContext` now uses `PhoenixStarterKitWeb.SentryScrubber.scrub_headers/1`. Sentry events do not get the `x-peek-auth` header.
- The session cookie keeps `same_site: "None"` and `secure: true`, because the iframe needs it.
- No data migration: the new tokens use the existing `partner_users_tokens` table.
