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

### 1) Run the Cloudflare setup script
This script replaces the manual Cloudflare UI steps (tunnel, service token, One-time PIN IdP, and Access app + policies)
and writes `.env` with your tunnel token.

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

```bash
export CLOUDFLARE_API_TOKEN="..."   # API token with Zero Trust + DNS permissions
export CLOUDFLARE_ACCOUNT_ID="..."
export CLOUDFLARE_ZONE_ID="..."
export APP_DOMAIN="<your-domain>.com"
export APP_SUBDOMAIN="myservice"
export ORIGIN_SERVICE="http://example-api:8000"
export TUNNEL_NAME="my-tunnel"
export ACCESS_APP_NAME="my-application"
export SERVICE_TOKEN_NAME="my-service-token"
export ALLOWED_EMAIL_DOMAIN="example.com"    # or ALLOWED_EMAILS="a@x.com,b@x.com"
# Optional:
export ACCESS_SESSION_DURATION="24h"
export SERVICE_TOKEN_DURATION="8760h"
export ENV_FILE_PATH="./.env"
export ENV_TEMPLATE_PATH="./.env.example"

./scripts/cloudflare-setup.sh
```

### 2) Bring your own Dockerized service
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
  - Replace **`<subdomain>`** and **`<your-domain>`** in the **`hostname`** line to your own values
  - Replace **`<container-name>`** with the service name you chose earlier, e.g. `my-service`
  - Replace **`<port>`** with the port your service's container listens on. For example, you might start your service with `--port 8000`; the port may be defined elsewhere in the code that your container runs; or your Dockerfile might have `EXPOSE 8000` (note: `EXPOSE` is helpful but not required to set in your Dockerfile).

### 3) Start the tunnel
```bash
cd src
docker compose up -d
```

## Security notes (read this)
- Do **not** publish your origin service with `ports:` in docker-compose unless you *really* mean to expose it outside Cloudflare Access.
  - `ports:` creates a second, direct entrypoint to the service that bypasses Access (host/LAN reachability, firewall mistakes, etc.).
  - If you need local debugging, bind to localhost only: `127.0.0.1:8000:8000`
- Never commit `.env` / tunnel tokens / service tokens. Rotate immediately if exposed.
- Cloudflare Access is the front door; your origin app still needs normal hardening (authz, input validation, rate limits, etc.).
