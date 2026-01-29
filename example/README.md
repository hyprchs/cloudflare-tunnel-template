# Example: FastAPI + Cloudflare Tunnel

This directory is a standalone, working example built from the template.
It keeps the same `cloudflared.yml` + `docker-compose.yml` layout and adds a tiny FastAPI service.

## Quickstart
Note: These instructions were tested on Mac only.

### 1) Create a Cloudflare Tunnel
a. Go to **Cloudflare Zero Trust**, then go to **Networks** → **Connectors** → **Create a tunnel** → **Select Cloudflared**

b. Set a **Tunnel name**, e.g. `example-tunnel`, and click **Save tunnel**

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
    - Set a value for **Subdomain**: `example`
    - Select your domain from the **Domain** dropdown, e.g. `<your-domain>.com`. Note: Your domain must be on Cloudflare and using Cloudflare DNS (nameservers pointed at Cloudflare), or the subdomain set in this step will not resolve correctly.
  - Under **Service**:
    - Select **Type**: `HTTP`
    - Set **URL**: `example-api:8000`. Here, `example-api` is the service name in this folder's `docker-compose.yml`, and `8000` is the port the container listens on.
  - Click **Complete setup**

### 2) Create a Service Token
a. While still in **Cloudflare Zero Trust**, go to **Access controls** → **Service credentials** → **Create Service Token**

b.
  - Set a **Service token name**, e.g. `example-service-token`
  - Select a **Service Token Duration**: `Non-expiring`
  - Click **Generate token**
  - Copy/save your **Header and client secret** for later, it's only available once on this screen.

### 3) Enable One-time PIN identity provider
While still in **Cloudflare Zero Trust**, go to **Integrations** → **Identity providers** → **Add an identity provider** → **One-time PIN**; it should show **Added**.

### 4) Create a Cloudflare Access app
a. While still in **Cloudflare Zero Trust**, go to **Access controls** → **Applications** → **Add an application** → **Select Self-hosted**

b.
  - Under **Basic information**:
    - Set an **Application name**, e.g. `example-app`
    - Select a **Session Duration** that works for you, e.g. `24 hours`. This sets the auth session duration for when visiting `example.<your-domain>.com`, after which you'll need to sign in again.
    - Click **Add public hostname**, then set values under it:
      - Select **Input method**: `Default`
      - Set **Subdomain** to `example`
      - Set **Domain** to `<your-domain>.com`
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
        - Select **Value** as the token name you created earlier, e.g. `example-service-token`
      - Click **Save** and go back to the previous tab
      - Click **Select existing policies** and choose the policy you just created
  - Under **Login methods**:
    - Turn on **Accept all available identity providers**. You should see **One-time PIN** availabe in the list below.
  - Click **Next**
  - Optional: Under **Application Appearance**, select **Use custom logo** and provide link to your website's favicon!
  - Click **Save**

### 5) Update `cloudflared.yml`
- Confirm `hostname` is set to `example.<your-domain>.com`
- Replace `<your-domain>` with your Cloudflare-managed domain
- Confirm `service` is set to `example-api:8000`

### 6) Start the tunnel
```bash
cp .env.example .env
docker compose up -d --build
```

## Security notes (read this)
- Do **not** publish your origin service with `ports:` in docker-compose unless you *really* mean to expose it outside Cloudflare Access.
  - `ports:` creates a second, direct entrypoint to the service that bypasses Access (host/LAN reachability, firewall mistakes, etc.).
  - If you need local debugging, bind to localhost only: `127.0.0.1:8000:8000`
- Never commit `.env` / tunnel tokens / service tokens. Rotate immediately if exposed.
- Cloudflare Access is the front door; your origin app still needs normal hardening (authz, input validation, rate limits, etc.).
