## Security notes (read this)
- Do **not** publish your origin service with `ports:` in docker-compose unless you *really* mean to expose it outside Cloudflare Access.
  - `ports:` creates a second, direct entrypoint to the service that bypasses Access (host/LAN reachability, firewall mistakes, etc.).
  - If you need local debugging, bind to localhost only: `127.0.0.1:8000:8000`
- Never commit `.env` / tunnel tokens / service tokens. Rotate immediately if exposed.
- Cloudflare Access is the front door; your origin app still needs normal hardening (authz, input validation, rate limits, etc.).

If a token is ever committed, assume it is compromised and rotate it.
