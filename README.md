# cloudflare-tunnel-template

Template repo for exposing a local service (UI or API) through Cloudflare Tunnel + Access.

This template provides a **starting point** (not a full setup) and instructions for making an arbitrary **self-hosted, Dockerized service**
available on a stable subdomain of your live Cloudflare-hosted website. This solves two main problems:

- Enables secure access to some local data without opening your entire machine to the public internet
- Provides stable URLs for tools that expect to be able to access your self-hosted services through permanent HTTPS endpoints

## Why this exists
At [Hyperchess](https://hyperchess.ai) ([GitHub](https://github.com/hyprchs/)), we tunnel a few key internal services to subdomains of https://hyperchess.ai:
- Viewers/dashboards for training data (https://trainingdata.hyperchess.ai)
- MLflow training observability (https://mlflow.hyperchess.ai)
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

### 1) Create a Cloudflare Tunnel
Cloudflare Zero Trust → **Networks** → **Tunnels**:
- Create a new tunnel (e.g., `local-mlflow`)
- Add a **Public Hostname**:
  - Hostname: `mlflow.<your-domain>` (example: `mlflow.hyperchess.ai`)
  - Service type: **HTTP**
  - Service URL: `http://host.docker.internal:5050` (use your local port)
  - If `cloudflared` is running in Docker (as in this repo), `127.0.0.1` points to the container, not your Mac.

### 2) Create a Cloudflare Access app
Cloudflare Zero Trust → **Access** → **Applications**:
- Create a **Self-hosted** app for `mlflow.<your-domain>`
- Add **two** policies:
  - Humans (browser UI): **Allow** (email / IdP group)
  - Jobs (API/service tokens): **Service Auth** (service token)

Cloudflare Zero Trust → **Access** → **Service Auth**:
- Create a service token (used by jobs or scripts)
- Attach it to the **Service Auth** policy

### 3) Put the tunnel token in `.env`
Cloudflare Zero Trust → **Networks** → **Tunnels** → your tunnel:
- Copy the **Tunnel token** (used by `cloudflared`)

Then:
```bash
cp compose/env.example .env
# Set CLOUDFLARE_TUNNEL_TOKEN=...
```

### 4) Update `config/cloudflared.yml`
- Set `hostname` to your public hostname (example: `mlflow.hyperchess.ai`)
- Set `service` to your local upstream
  - If your service runs on the host: `http://host.docker.internal:5050`
  - If your service runs in Docker: use its container name on a shared network

### 5) Start the tunnel
```bash
docker compose up -d
```

## Files
- `compose/docker-compose.yml` — runs cloudflared
- `compose/env.example` — your token
- `config/cloudflared.yml` — hostname + upstream mapping
