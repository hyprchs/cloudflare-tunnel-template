# cloudflare-tunnel-template

Template repo for exposing a local service (UI or API) through Cloudflare Tunnel + Access.

This template provides a **starting point** (not a full setup) and instructions for making an arbitrary **self-hosted, Dockerized service**
available on a stable subdomain of your live Cloudflare-hosted website. This solves two main problems:

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

### 1) Create a Cloudflare Tunnel
a. Go to **Cloudflare Zero Trust**, then go to **Networks** → **Connectors** → **Create a tunnel** → **Select Cloudflared**

b. Set a **Tunnel name**, e.g. `my-tunnel`, and click **Save tunnel**

c. Choose your environment (OS), **Mac**

d. If you do not already have `cloudflared` installed (check with `which cloudflared`), now is a good time to run `brew install cloudflared` as this page recommends

e. Copy one of the code blocks to get the tunnel token. It isn't shown in full on this page, but you can paste the result somewhere, then copy the full token part.
   Create `.env` from `.env.example`:
   ```bash
   cp .env.example .env
   ```
   and paste in the token: `CLOUDFLARE_TUNNEL_TOKEN=<token>`. Back in Cloudflare, click **Next**.

f.
  - Under **Hostname**:
    - Set a value for **Subdomain**, e.g. `myservice`
    - Select your domain from the **Domain** dropdown, e.g. `<your-domain>.com`. Note: Your domain must be on Cloudflare and using Cloudflare DNS (nameservers pointed at Cloudflare), or the subdomain set in this step will not resolve correctly.
  - Under **Service**:
    - Select **Type**: `HTTP`
    - Set **URL**: `<container-name>:<port>`, e.g. `example-api:8000`. Here, `container-name` should be the name of your Docker service (which you'll need to set in `src/docker-compose.yml` next to the existing `cloudflared` service), and `port` should be the port that your service's container listens on. See [example/](example/) for a minimal example setup.
  - Click **Complete setup**

### 2) Create a Service Token
a. While still in **Cloudflare Zero Trust**, go to **Access controls** → **Service credentials** → **Create Service Token**

b.
  - Set a **Service token name**, e.g. `my-service-token`
  - Select a **Service Token Duration**: `Non-expiring`
  - Click **Generate token**
  - Copy/save your **Header and client secret** for later, it's only available once on this screen.

### 3) Enable One-time PIN identity provider
While still in **Cloudflare Zero Trust**, go to **Integrations** → **Identity providers** → **Add an identity provider** → **One-time PIN**; it should show **Added**.

### 4) Create a Cloudflare Access app
a. While still in **Cloudflare Zero Trust**, go to **Access controls** → **Applications** → **Add an application** → **Select Self-hosted**

b.
  - Under **Basic information**:
    - Set an **Application name**, e.g. `my-application`
    - Select a **Session Duration** that works for you, e.g. `24 hours`. This sets the auth session duration for when visiting `myservice.<your-domain>.com`, after which you'll need to sign in again.
    - Click **Add public hostname**, then set values under it:
      - Select **Input method**: `Default`
      - Set **Subdomain** to the same value as before, e.g. `myservice`
      - Set **Domain** to the same value as before, e.g. `<your-domain>.com`
  - Under **Access policies**, we'll create two new policies:
    - Policy 1:
      - Click **Create new policy**. This will open a new tab.
      - Under **Basic Information**:
        - Set **Policy name**: `Humans/browser`
        - Select **Action**: `Allow`
        - Select **Session duration**: `Same as application session timeout`
      - Under **Add rules** → **Include (OR)**:
        - Define who you want to be able to get through the auth guard at your service in the browser. For example, select **Selector**: `Emails`, and enter specific emails in **Value**, or select **Selector**: `Emails ending in` with **Value**: `@<your-company>.com`.
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

### 5) Update `src/cloudflared.yml`
- Set `hostname` to your public hostname (example: `<subdomain>.<your-domain>.com`)
- Replace `<your-domain>` with your Cloudflare-managed domain
- Replace `<subdomain>` with the subdomain you want to expose
- Set `service` to your local Dockerized service
  - Replace `<port>` with the port your local service's container listens on
  - Replace `<container-name>` with your local service's name on the same Docker network (e.g. `http://example-api:8000`)
- TODO: Simplify/edit instructions above to read more similarly to previous steps (check against `src/cloudflared.yml` to be sure these instructions are still accurate and minimal)

### 6) Start the tunnel
```bash
docker compose -f src/docker-compose.yml up -d
```

## Project structure
- `src/` — template cloudflared config + compose file
- `example/` — standalone FastAPI example (with its own README)
