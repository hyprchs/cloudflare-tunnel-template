# Example: FastAPI + Cloudflare Tunnel

This directory is a standalone, working example built from the template.
It keeps the same `cloudflared.yml` + `docker-compose.yml` layout and adds a tiny FastAPI service.

## Quickstart (example values)

### 1) Create a Cloudflare Tunnel
- **Subdomain**: `example`
- **Domain**: `<your-domain>.com`
- **Service type**: `HTTP`
- **URL**: `example-api:8000`

### 2) Create a Service Token
Create a non-expiring Service Token in Cloudflare Zero Trust and save the client ID + secret.

### 3) Create a Cloudflare Access app
- Use the same hostname as above (`example.<your-domain>.com`)
- Add two policies: Humans (Allow) + Jobs (Service Auth)

### 4) Update local files
- `cloudflared.yml`: replace `<your-domain>.com` with your domain
- `.env`: paste your `CLOUDFLARE_TUNNEL_TOKEN`

### 5) Start the example
```bash
cp .env.example .env
docker compose up -d --build
```
