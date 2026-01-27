# cloudflare-tunnel-template

Template repo for exposing a local service (UI or API) through Cloudflare Tunnel + Access.

## What this does
- runs `cloudflared` with a tunnel token
- routes a public hostname to a local port
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
