# cloudflare-tunnel-template

Template repo for exposing a local service (UI or API) through Cloudflare Tunnel + Access.

## Why this exists
At Hyperchess, we run key services (MLflow, data viewers, local dashboards, even inference servers) on a laptop.
This template makes them reachable at a stable Hyperchess subdomain without moving data to the cloud.
It solves two problems:
- **Stable URLs** for tools that need a permanent endpoint (e.g., `mlflow.hyperchess.ai`)
- **Private access** without opening your laptop to the public internet

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

## Possible use cases
- Local MLflow UI with a stable URL (see [`mlflow-stack`](https://github.com/hyprchs/mlflow-stack))
- A local FastAPI inference server for your CLM (chat/completions API)
- A local dashboard for datasets or training metrics
