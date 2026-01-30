# cloudflare-tunnel-template

Template repo for exposing a local service (UI or API) through Cloudflare Tunnel + Access.

### Project structure
```
├╴src/      # Template cloudflared config + compose file
└╴example/  # Standalone example implementation of the template
```

This template provides a **starting point** and instructions for making an arbitrary **self-hosted, Dockerized service**
available on a stable subdomain of a live Cloudflare-hosted website. This solves two main problems:

- Enables secure access to some local data without opening your entire machine to the public internet
- Provides stable URLs for tools that expect to be able to access your self-hosted services through permanent HTTPS endpoints

## Why this exists
At [Hyperchess](https://hyperchess.ai) ([GitHub](https://github.com/hyprchs/)), we tunnel a few key internal services to subdomains of https://hyperchess.ai:
- Viewers/dashboards for training data (https://trainingdata.hyperchess.ai)
- MLflow for training observability (https://mlflow.hyperchess.ai)
- Inference servers for chat completion requests, running on a local GPU! (https://api.hyperchess.ai)

This lets us self-host our full microservice stack during development (from a laptop!), keeping cloud costs at $0,
and progressively transition to cloud providers as-needed while we scale.

A few other notes:
- Subdomains will be protected by an auth check (current instructions show how to allow only `@hyperchess.ai` emails to log in, but this can be adjusted for your setup)
- Any paths that you mount to the local/self-hosted service's Docker container can be made available on the subdomain too (after auth; e.g. make your service read & display that data
  in a [frontend](https://github.com/jacksonthall22/sveltekit-supabase), or allow it to be downloaded via an S3-like API), bypassing the need for cloud storage!
- If your local container exposing the service isn't running, the live subdomain will simply be unavailable (giving a 503 error). That is, if you want to be extra sure
  your machine isn't exposed (even though the recommended setup is already secure), just stop the local container to break the tunnel.

## Quickstart
Note: These instructions were tested on Mac only.

### 1) Bring your own Dockerized service
- Edit `src/docker-compose.yml` by adding your service under **`services:`**. Choose whatever name you like for the service, e.g. `my-service` (you'll use this in the next step).
  Use one of these two patterns:
  - Build from a local Dockerfile:
    - Put a `Dockerfile` in a folder, e.g. under `./my-service/`
    - Add this to **`src/docker-compose.yml`**:
      ```yaml
      services:
        cloudflared:
          ...
        my-service:
          build:
            context: ./my-service
      ```
  - Use a prebuilt image:
    - Add this to **`src/docker-compose.yml`**:
      ```yaml
      services:
        cloudflared:
          ...
        my-service:
          image: my-org/my-image:latest
      ```
- Update **`src/cloudflared.yml`**:
  - Replace **`<subdomain>`** and **`<mydomain.com>`** in the **`hostname`** line to your own values
  - Replace **`<service-name>`** with the service name you chose earlier, e.g. `my-service`.
  - Replace **`<port>`** with the port your service's container listens on. For example, you might start your service with `--port 8000`; the port may be defined elsewhere in the code that your container runs; or your Dockerfile might have `EXPOSE 8000` (note: `EXPOSE` is helpful but not required to set in your Dockerfile).
  - Note: You’ll use the same subdomain, service name, and port in Step 2.

### 2) Set up Cloudflare (choose one)
Pick exactly one of the two options below. Both end with the same Cloudflare setup (tunnel + Access app + policies).

<details>

<summary>Option A (recommended): Run the Cloudflare setup script</summary>

This script replaces the manual Cloudflare UI steps (tunnel, service token, One-time PIN IdP, and Access app + policies),
write `.env` file with your tunnel token, and writes an `.env.example` file.

#### Prerequisites

- [Create an API token](https://dash.cloudflare.com/profile/api-tokens) (**Create Token** → **Create Custom Token**) so the setup script has permission to add the required application/policies/tunnel on your Cloudflare account:

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
  | `APP_DOMAIN` | Your domain | `mydomain.com` |
  | `APP_SUBDOMAIN` | Subdomain to create | `myservice` |
  | `ORIGIN_SERVICE` | Internal URL to your service container (service name comes from `docker-compose.yml` in Step 1) | `http://my-service:8000` |
  | `TUNNEL_NAME` | Tunnel name | `my-tunnel` |
  | `ACCESS_APP_NAME` | Access app name | `my-application` |
  | `SERVICE_TOKEN_NAME` | Service token name | `my-service-token` |
  | `ALLOWED_EMAIL_DOMAIN` | Auth allowlist by email domain | `mydomain.com` to allow all `@mydomain.com` users |
  | `ALLOWED_EMAILS` | Auth allowlist by specific emails | `a@mydomain.com,b@mydomain.com` to allow specific users |
  | `ACCESS_SESSION_DURATION` | Optional session duration for humans | `24h` |
  | `SERVICE_TOKEN_DURATION` | Optional service token duration | `8760h` |
  | `ENV_FILE_PATH` | Optional `.env` output path (change to avoid overwriting an existing one) | `./.env` |
  | `ENV_TEMPLATE_PATH` | Optional `.env.example` template output path (change to avoid overwriting an existing one) | `./.env.example` |

  ```bash
  export CLOUDFLARE_API_TOKEN="..."
  export CLOUDFLARE_ACCOUNT_ID="..."
  export CLOUDFLARE_ZONE_ID="..."

  export APP_DOMAIN="mydomain.com"
  export APP_SUBDOMAIN="myservice"
  export ORIGIN_SERVICE="http://my-service:8000"

  export TUNNEL_NAME="my-tunnel"
  export ACCESS_APP_NAME="my-application"
  export SERVICE_TOKEN_NAME="my-service-token"

  export ALLOWED_EMAIL_DOMAIN="mydomain.com"
  export ALLOWED_EMAILS="a@mydomain.com,b@mydomain.com"

  export ACCESS_SESSION_DURATION="24h"
  export SERVICE_TOKEN_DURATION="8760h"

  export ENV_FILE_PATH="./.env"
  export ENV_TEMPLATE_PATH="./.env.example"
  ```
  
- In the same shell, run the script:
  ```sh
  ./scripts/cloudflare-setup.sh
  ```

</details>

<details>

<summary>Option B: Manual setup in the Cloudflare dashboard</summary>

#### 1) Create a Cloudflare Tunnel
a. Go to **Cloudflare Zero Trust**, then go to **Networks** → **Connectors** → **Create a tunnel** → **Select Cloudflared**.

b. Set a **Tunnel name**, e.g. `my-tunnel`, and click **Save tunnel**.

c. Choose your environment (OS), **Mac**.

d. If you do not already have `cloudflared` installed (check with `which cloudflared`), now is a good time to run `brew install cloudflared` as this screen recommends.

e. Copy one of the code blocks to get the tunnel token. It isn't shown in full on this page, but you can paste the result somewhere, then copy the full token part.
   Create `.env` from `.env.example`:
   ```bash
   cp .env.example .env
   ```
   and paste in the token: `CLOUDFLARE_TUNNEL_TOKEN=<token>`. Back in Cloudflare, click **Next**.

f.
  - Under **Hostname**:
    - Set a value for **Subdomain**, e.g. `myservice`
    - Select your domain from the **Domain** dropdown, e.g. `<mydomain.com>`. Note: Your domain must be on Cloudflare and using Cloudflare DNS (nameservers pointed at Cloudflare), or the subdomain set in this step will not resolve correctly.
  - Under **Service**:
    - Select **Type**: `HTTP`
    - Set **URL**: `<service-name>:<port>`, e.g. `example-api:8000`. Use the service name + port you set in Step 1. See [example/](example/) for a minimal example setup.
  - Click **Complete setup**

#### 2) Create a Service Token
a. While still in **Cloudflare Zero Trust**, go to **Access controls** → **Service credentials** → **Create Service Token**

b.
  - Set a **Service token name**, e.g. `my-service-token`
  - Select a **Service Token Duration**: `Non-expiring`
  - Click **Generate token**
  - Copy/save your **Header and client secret** for later, it's only available once on this screen.

#### 3) Enable One-time PIN identity provider
While still in **Cloudflare Zero Trust**, go to **Integrations** → **Identity providers** → **Add an identity provider** → **One-time PIN**; it should show **Added**.

#### 4) Create a Cloudflare Access app
a. While still in **Cloudflare Zero Trust**, go to **Access controls** → **Applications** → **Add an application** → **Select Self-hosted**

b.
  - Under **Basic information**:
    - Set an **Application name**, e.g. `my-application`
    - Select a **Session Duration** that works for you, e.g. `24 hours`. This sets the auth session duration for when visiting `myservice.<mydomain.com>`, after which you'll need to sign in again.
    - Click **Add public hostname**, then set values under it:
      - Select **Input method**: `Default`
      - Set **Subdomain** to the same value as before, e.g. `myservice`
      - Set **Domain** to the same value as before, e.g. `<mydomain.com>`
  - Under **Access policies**, we'll create two new policies:
    - Policy 1:
      - Click **Create new policy**. This will open a new tab.
      - Under **Basic Information**:
        - Set **Policy name**: `Humans/browser`
        - Select **Action**: `Allow`
        - Select **Session duration**: `Same as application session timeout`
      - Under **Add rules** → **Include (OR)**:
        - Define who you want to be able to get through the auth guard at your service in the browser. For example, select **Selector**: `Emails`, and enter specific emails in **Value**, or select **Selector**: `Emails ending in` with **Value**: `@<mydomain.com>`.
      - Click **Save** and go back to the previous tab
      - Click **Select existing policies** and choose the policy you just created
    - Policy 2:
      - Click **Create new policy**. This will open a new tab.
      - Under **Basic Information**:
        - Set **Policy name**: `Jobs/non-interactive`
        - Select **Action**: `Service Auth`
        - Select **Session duration**: `No duration, expires immediately`
      - Under **Add rules** → **Include (OR)**:
        - Select **Selector**: `Service Token`
        - Select **Value** as the token name you created earlier, e.g. `my-service-token`
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
cd src
docker compose up -d
```

## Security notes
- Do **not** publish your origin service with `ports:` in docker-compose unless you know what you're doing and mean to expose it outside Cloudflare Access.
  - `ports:` creates a second, direct entrypoint to the service that bypasses Access (allows host/LAN reachability, exposes you to vulnerabilities if you have firewall mistakes, etc.).
  - If you need local debugging, bind to localhost only: `127.0.0.1:8000:8000`, **NOT** `0.0.0.0`
- Never commit `.env` / tunnel tokens / service tokens. Rotate immediately if exposed.
- Cloudflare Access is the front door; your origin app still needs normal hardening (authz, input validation, rate limits, etc.).
