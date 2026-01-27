# cloudflare-tunnel-template

Template repo for exposing a local service (UI or API) through Cloudflare Tunnel + Access.

## Why this exists (Hyperchess context)
We run key services (MLflow, data viewers, local dashboards, even inference servers) on a laptop.
This template makes them reachable at a stable Hyperchess subdomain without moving data to the cloud.
It solves two problems:
- **Stable URLs** for tools that need a permanent endpoint (e.g., `mlflow.hyperchess.ai`)
- **Private access** without opening your laptop to the public internet

## What this does
- runs `cloudflared` with a tunnel token
- maps a public hostname to a local port
- keeps access locked behind Cloudflare Access

## Quickstart
1) Create a Cloudflare Tunnel + Access app
2) Put the tunnel token in `.env`
3) Run `docker compose up -d`

## Files
- `compose/docker-compose.yml` — runs cloudflared
- `compose/env.example` — your token + settings

## Possible use cases
- Local MLflow UI with a stable URL (see [`mlflow-stack`](https://github.com/hyprchs/mlflow-stack))
- A local FastAPI inference server for your CLM (chat/completions API)
- A local dashboard for datasets or training metrics
