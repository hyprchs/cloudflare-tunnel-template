<div align="center">
  <h1>cloudflare-tunnel-template</h1>
  <p>
    <img alt="Cloudflare Tunnel" src="https://img.shields.io/badge/Cloudflare-Tunnel-F38020?logo=cloudflare&logoColor=white" />
    <img alt="Cloudflare Access" src="https://img.shields.io/badge/Cloudflare-Access-F38020?logo=cloudflare&logoColor=white" />
    <img alt="Docker Compose" src="https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white" />
  </p>
  <p>
    <a href="#project-structure">Project structure</a> |
    <a href="#quickstart">Quickstart</a> |
    <a href="#security-notes">Security notes</a>
  </p>
</div>

---

Example: FastAPI + Cloudflare Tunnel.
This directory is a standalone, working example built from the template.
It keeps the same `cloudflared.yml` + `docker-compose.yml` layout and adds a tiny FastAPI service.

### Project structure
```
example/
|-- example-api/        # FastAPI app + Dockerfile
|-- cloudflared.yml     # Tunnel ingress config
`-- docker-compose.yml  # cloudflared + example-api
```

## Quickstart
Note: These instructions were tested on Mac only.

### 1) Review the example service
- The example service is in `example/example-api/` and listens on port `8000`.
- `example/docker-compose.yml` already wires `example-api` + `cloudflared` together.
- Update `example/cloudflared.yml`:
  - Replace `<your-domain>` with your Cloudflare-managed domain.
  - Optionally change the subdomain (`example`) to whatever you want.
  - Keep `service: http://example-api:8000` unless you change the container port.

### 2) Set up Cloudflare (choose one)
Pick exactly one of the two options below. Both end with the same Cloudflare setup (tunnel + Access app + policies).

<details>

<summary>Option A (recommended): Run the Cloudflare setup script</summary>

This script replaces the manual Cloudflare UI steps (tunnel, service token, One-time PIN IdP, and Access app + policies),
writes `example/.env` with your tunnel token, and writes an `example/.env.example` file.

#### Prerequisites

- [Create an API token](https://dash.cloudflare.com/profile/api-tokens) (**Create Token** -> **Create Custom Token**) so the setup script has permission to add the required application/policies/tunnel on your Cloudflare account:

  <img width="875" height="211" alt="image" src="https://github.com/user-attachments/assets/341d61e8-1b9b-4322-b7f0-f612019ec85b" />

  Optional: Under **Account Resources**, **Include** only the Cloudflare account that manages your domain.

  Optional: Select **TTL End Date** to be short-lived, e.g. one day in the future (you'll only need this key once for running the setup script).

- [Find your Cloudflare **Account ID** and **Zone ID**](https://developers.cloudflare.com/fundamentals/account/find-account-and-zone-ids/)

- Export env vars. Important: Be sure to set at least one of `ALLOWED_EMAIL_DOMAIN` or `ALLOWED_EMAILS` (both also works).

  | Env var | Description | Example |
  | --- | --- | --- |
  | `CLOUDFLARE_API_TOKEN` | API token from the dashboard | `...` |
  | `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account ID | `...` |
  | `CLOUDFLARE_ZONE_ID` | Cloudflare zone ID | `...` |
  | `APP_DOMAIN` | Your domain | `your-domain.com` |
  | `APP_SUBDOMAIN` | Subdomain to create | `example` |
  | `ORIGIN_SERVICE` | Internal URL to the example container | `http://example-api:8000` |
  | `TUNNEL_NAME` | Tunnel name | `example-tunnel` |
  | `ACCESS_APP_NAME` | Access app name | `example-app` |
  | `SERVICE_TOKEN_NAME` | Service token name | `example-service-token` |
  | `ALLOWED_EMAIL_DOMAIN` | Auth allowlist by email domain | `example.com` to allow all `@example.com` users |
  | `ALLOWED_EMAILS` | Auth allowlist by specific emails | `a@example.com,b@example.com` to allow specific users |
  | `ACCESS_SESSION_DURATION` | Optional session duration for humans | `24h` |
  | `SERVICE_TOKEN_DURATION` | Optional service token duration | `8760h` |
  | `ENV_FILE_PATH` | Optional `.env` output path (change to avoid overwriting an existing one) | `example/.env` |
  | `ENV_TEMPLATE_PATH` | Optional `.env.example` template output path (change to avoid overwriting an existing one) | `example/.env.example` |

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
  export ALLOWED_EMAILS="a@example.com,b@example.com"

  export ACCESS_SESSION_DURATION="24h"
  export SERVICE_TOKEN_DURATION="8760h"

  export ENV_FILE_PATH="example/.env"
  export ENV_TEMPLATE_PATH="example/.env.example"
  ```

- In the same shell, run the script:
  ```sh
  ./scripts/cloudflare-setup.sh
  ```

</details>

<details>

<summary>Option B: Manual setup in the Cloudflare dashboard</summary>

#### 1) Create a Cloudflare Tunnel

a. Go to **Cloudflare Zero Trust**, then go to **Networks** -> **Connectors** -> **Create a tunnel** -> **Select Cloudflared**.

b. Set a **Tunnel name**, e.g. `example-tunnel`, and click **Save tunnel**.

c. Choose your environment (OS), **Mac**.

d. If you do not already have `cloudflared` installed (check with `which cloudflared`), now is a good time to run `brew install cloudflared` as this screen recommends.

e. Copy one of the code blocks to get the tunnel token. It isn't shown in full on this page, but you can paste the result somewhere, then copy the full token part.
   Create `.env` from `.env.example`:
   ```bash
   cp example/.env.example example/.env
   ```
   and paste in the token: `CLOUDFLARE_TUNNEL_TOKEN=<token>`. Back in Cloudflare, click **Next**.

f.
  - Under **Hostname**:
    - Set a value for **Subdomain**, e.g. `example`
    - Select your domain from the **Domain** dropdown, e.g. `<your-domain.com>`. Note: Your domain must be on Cloudflare and using Cloudflare DNS (nameservers pointed at Cloudflare), or the subdomain set in this step will not resolve correctly.
  - Under **Service**:
    - Select **Type**: `HTTP`
    - Set **URL**: `example-api:8000`. This is the service name + port from `example/docker-compose.yml`.
  - Click **Complete setup**

#### 2) Create a Service Token

a. While still in **Cloudflare Zero Trust**, go to **Access controls** -> **Service credentials** -> **Create Service Token**

b.
  - Set a **Service token name**, e.g. `example-service-token`
  - Select a **Service Token Duration**: `Non-expiring`
  - Click **Generate token**
  - Copy/save your **Header and client secret** for later, it's only available once on this screen.

#### 3) Enable One-time PIN identity provider
While still in **Cloudflare Zero Trust**, go to **Integrations** -> **Identity providers** -> **Add an identity provider** -> **One-time PIN**; it should show **Added**.

#### 4) Create a Cloudflare Access app

a. While still in **Cloudflare Zero Trust**, go to **Access controls** -> **Applications** -> **Add an application** -> **Select Self-hosted**

b.
  - Under **Basic information**:
    - Set an **Application name**, e.g. `example-app`
    - Select a **Session Duration** that works for you, e.g. `24 hours`. This sets the auth session duration for when visiting `example.<your-domain.com>`, after which you'll need to sign in again.
    - Click **Add public hostname**, then set values under it:
      - Select **Input method**: `Default`
      - Set **Subdomain** to the same value as before, e.g. `example`
      - Set **Domain** to the same value as before, e.g. `<your-domain.com>`
  - Under **Access policies**, we'll create two new policies:
    - Policy 1:
      - Click **Create new policy**. This will open a new tab.
      - Under **Basic Information**:
        - Set **Policy name**: `Humans/browser`
        - Select **Action**: `Allow`
        - Select **Session duration**: `Same as application session timeout`
      - Under **Add rules** -> **Include (OR)**:
        - Define who you want to be able to get through the auth guard at your service in the browser. For example, select **Selector**: `Emails`, and enter specific emails in **Value**, or select **Selector**: `Emails ending in` with **Value**: `@<your-domain.com>`.
      - Click **Save** and go back to the previous tab
      - Click **Select existing policies** and choose the policy you just created
    - Policy 2:
      - Click **Create new policy**. This will open a new tab.
      - Under **Basic Information**:
        - Set **Policy name**: `Jobs/non-interactive`
        - Select **Action**: `Service Auth`
        - Select **Session duration**: `No duration, expires immediately`
      - Under **Add rules** -> **Include (OR)**:
        - Select **Selector**: `Service Token`
        - Select **Value** as the token name you created earlier, e.g. `example-service-token`
      - Click **Save** and go back to the previous tab
      - Click **Select existing policies** and choose the policy you just created
  - Under **Login methods**:
    - Turn on **Accept all available identity providers**. You should see **One-time PIN** availabe in the list below.
  - Click **Next**
  - Optional: Under **Application Appearance**, select **Use custom logo** and provide link to your website's favicon!
  - Under **401 Response for Service Auth policies**, turn on **Return 401 response**. This makes it so unauthenticated API clients get a 401 instead of a login page.
  - Click **Save**

</details>

### 3) Start the tunnel
```bash
cd example
docker compose up -d --build
```

## Security notes
- Do **not** publish your origin service with `ports:` in docker-compose unless you know what you're doing and mean to expose it outside Cloudflare Access.
  - `ports:` creates a second, direct entrypoint to the service that bypasses Access (allows host/LAN reachability, exposes you to vulnerabilities if you have firewall mistakes, etc.).
  - If you need local debugging, bind to localhost only: `127.0.0.1:8000:8000`, **NOT** `0.0.0.0`
- Never commit `.env` / tunnel tokens / service tokens. Rotate immediately if exposed.
- Cloudflare Access is the front door; your origin app still needs normal hardening (authz, input validation, rate limits, etc.).
