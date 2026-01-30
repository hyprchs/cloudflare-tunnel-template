# Example: FastAPI + Cloudflare Tunnel

This directory is a standalone, working example built from the template.
It keeps the same `cloudflared.yml` + `docker-compose.yml` layout and adds a tiny FastAPI service.

## Quickstart
Note: These instructions were tested on Mac only.

### 1) Run the Cloudflare setup script
This replaces the manual Cloudflare UI steps and writes `example/.env` with your tunnel token.
Run this from the repo root.

#### Prerequisites (quick links)
- `CLOUDFLARE_API_TOKEN`: create a custom API token in the Cloudflare dashboard:
  ```
  https://dash.cloudflare.com/profile/api-tokens
  ```
  When creating the token, select these specific permissions:
  - Account > Cloudflare Tunnel > Edit
  - Account > Access: Apps and Policies > Edit
  - Account > Access: Organizations, Identity Providers, and Groups > Edit
  - Account > Access: Service Tokens > Edit
  - Zone > DNS > Edit
  The tunnel + DNS requirements are documented in the Cloudflare Tunnel API guide, and the Access + IdP permissions are
  documented in the Access API references for applications and identity providers.
  Full list of permission names: https://developers.cloudflare.com/fundamentals/api/reference/permissions/
- `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_ZONE_ID`: open Account Home, select your site, and copy the IDs from the
  **API** section on the Overview page (Cloudflare docs with screenshots):
  ```
  https://dash.cloudflare.com/
  https://developers.cloudflare.com/fundamentals/account/find-account-and-zone-ids/
  ```

- Env vars (one per row):

  | Env var | Description | Example |
  | --- | --- | --- |
  | `CLOUDFLARE_API_TOKEN` | API token from the dashboard | `...` |
  | `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account ID | `...` |
  | `CLOUDFLARE_ZONE_ID` | Cloudflare zone ID | `...` |
  | `APP_DOMAIN` | Your domain | `your-domain.com` |
  | `APP_SUBDOMAIN` | Subdomain to create | `example` |
  | `ORIGIN_SERVICE` | Internal URL to the example container (`example-api` in `example/docker-compose.yml`) | `http://example-api:8000` |
  | `TUNNEL_NAME` | Tunnel name | `example-tunnel` |
  | `ACCESS_APP_NAME` | Access app name | `example-app` |
  | `SERVICE_TOKEN_NAME` | Service token name | `example-service-token` |
  | `ALLOWED_EMAIL_DOMAIN` | Allowlist by email domain (set at least one allowlist value) | `example.com` |
  | `ALLOWED_EMAILS` | Allowlist by specific emails (set at least one allowlist value) | `a@x.com,b@x.com` |
  | `ACCESS_SESSION_DURATION` | Optional session duration for humans | `24h` |
  | `SERVICE_TOKEN_DURATION` | Optional service token duration | `8760h` |
  | `ENV_FILE_PATH` | Optional `.env` output path | `example/.env` |
  | `ENV_TEMPLATE_PATH` | Optional `.env.example` template path | `example/.env.example` |

- Set at least one of `ALLOWED_EMAIL_DOMAIN` or `ALLOWED_EMAILS` (both also works).

- Export env vars (single copy/paste block):
  ```bash
  export CLOUDFLARE_API_TOKEN="..."
  export CLOUDFLARE_ACCOUNT_ID="..."
  export CLOUDFLARE_ZONE_ID="..."

  export APP_DOMAIN="your-domain.com"
  export APP_SUBDOMAIN="example"
  export ORIGIN_SERVICE="http://example-api:8000"

  export TUNNEL_NAME="example-tunnel"
  export ACCESS_APP_NAME="example-app"
  export SERVICE_TOKEN_NAME="example-service-token"

  export ALLOWED_EMAIL_DOMAIN="example.com"
  export ALLOWED_EMAILS="a@x.com,b@x.com"

  export ACCESS_SESSION_DURATION="24h"
  export SERVICE_TOKEN_DURATION="8760h"

  export ENV_FILE_PATH="example/.env"
  export ENV_TEMPLATE_PATH="example/.env.example"
  ```

- Run the script from the repo root (same shell as exports):
  ```bash
  ./scripts/cloudflare-setup.sh
  ```

### 2) Update `cloudflared.yml`
- Confirm `hostname` is set to `example.<your-domain>.com`
- Replace `<your-domain>` with your Cloudflare-managed domain
- Confirm `service` is set to `example-api:8000`

### 3) Start the tunnel
```bash
cd example
docker compose up -d --build
```

## Security notes (read this)
- Do **not** publish your origin service with `ports:` in docker-compose unless you *really* mean to expose it outside Cloudflare Access.
  - `ports:` creates a second, direct entrypoint to the service that bypasses Access (host/LAN reachability, firewall mistakes, etc.).
  - If you need local debugging, bind to localhost only: `127.0.0.1:8000:8000`
- Never commit `.env` / tunnel tokens / service tokens. Rotate immediately if exposed.
- Cloudflare Access is the front door; your origin app still needs normal hardening (authz, input validation, rate limits, etc.).
