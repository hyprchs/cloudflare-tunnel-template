# cloudflare-tunnel-template

Template repo for exposing a local service (UI or API) through Cloudflare Tunnel + Access.

## Why this exists
At Hyperchess, we tunnel a few key internal services to subdomains of https://hyperchess.ai by running and serving the entire stack from a single machine:
- MLflow training observability (https://mlflow.hyperchess.ai)
- data viewers/dashboards (https://trainingdata.hyperchess.ai)
- even inference servers that run on a local GPU.
This allows us to self-host the entire production stack locally (from a laptop!) and keep costs at $0 during development, while also providing a clear path for transitioning individual microservices to cloud providers as-needed when we scale.

This template provides a starting point and instructions for making an arbitrary REST server reachable at a stable Hyperchess subdomain. This solves two problems:

- Provides stable URLs for tools that need a permanent endpoint (e.g., displaying local experiment tracking observability data as if it's cloud-hosted on https://mlflow.hyperchess.ai)
- Private access without opening your laptop to the public internet

A few other notes:
- Subdomains will be protected by an auth check (current instructions only allow @hyperchess.ai emails to log in, but this can be adjusted)
- Any paths on your local filesystem that are mounted to the local/self-hosted service's Docker container can be made available in the subdomain, essentially bypassing the need for S3-style cloud storage (at least for now)!
- If your local container exposing the REST server isn't running, the live subdomain will simply be unavailable. That is, the setup is already secure, but if you're running from a laptop and want to be extra sure your machine isn't accessible, just stop the local container to break the tunnel.

## What this does
- runs `cloudflared` with a tunnel token
- maps a public hostname to a local port
- keeps access locked behind Cloudflare Access

## Quickstart

### 1) Create a Cloudflare Tunnel
Cloudflare Zero Trust → **Networks** → **Tunnels**:
- Create a new tunnel (e.g., `local-mlflow`)
- Add a **Public Hostname**:
  - Hostname: `mlflow.<your-domain>` (example: `mlflow.hyperchess.ai`)
  - Service type: **HTTP**
  - Service URL: `http://127.0.0.1:5050` (or your local port)

### 2) Create a Cloudflare Access app
Cloudflare Zero Trust → **Access** → **Applications**:
- Create a **Self-hosted** app for `mlflow.<your-domain>`
- Add **two** policies:
  - Humans (browser UI): **Allow** (email / IdP group)
  - Jobs (API/service tokens): **Service Auth** (service token)

### 3) Put the tunnel token in `.env`
Cloudflare Zero Trust → **Networks** → **Tunnels** → your tunnel:
- Copy the **Tunnel token** (used by `cloudflared`)

Then:
```bash
cp compose/env.example .env
# Set CLOUDFLARE_TUNNEL_TOKEN=...
```

### 4) Start the tunnel
```bash
docker compose up -d
```

## Files
- `compose/docker-compose.yml` — runs cloudflared
- `compose/env.example` — your token + settings
