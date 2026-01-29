#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Step mapping (from README steps 1-4):
# 1) Create tunnel + DNS + ingress config (see "Step 1" section below)
# 2) Create service token (see "Step 2" section below)
# 3) Enable One-time PIN identity provider (see "Step 3" section below)
# 4) Create Access app + policies (see "Step 4" section below)

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

require_env() {
  local var="$1"
  if [ -z "${!var:-}" ]; then
    echo "Missing required env var: $var" >&2
    exit 1
  fi
}

require_cmd curl
require_cmd jq

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

require_env CLOUDFLARE_API_TOKEN
require_env CLOUDFLARE_ACCOUNT_ID
require_env CLOUDFLARE_ZONE_ID
require_env APP_DOMAIN
require_env APP_SUBDOMAIN
require_env ORIGIN_SERVICE
require_env TUNNEL_NAME
require_env ACCESS_APP_NAME
require_env SERVICE_TOKEN_NAME

ACCESS_SESSION_DURATION="${ACCESS_SESSION_DURATION:-24h}"
SERVICE_TOKEN_DURATION="${SERVICE_TOKEN_DURATION:-}"
ALLOWED_EMAILS="${ALLOWED_EMAILS:-}"
ALLOWED_EMAIL_DOMAIN="${ALLOWED_EMAIL_DOMAIN:-}"
ENV_FILE_PATH="${ENV_FILE_PATH:-${repo_root}/.env}"
ENV_TEMPLATE_PATH="${ENV_TEMPLATE_PATH:-}"

if [ -z "$ALLOWED_EMAILS" ] && [ -z "$ALLOWED_EMAIL_DOMAIN" ]; then
  echo "Set ALLOWED_EMAILS (comma-separated) or ALLOWED_EMAIL_DOMAIN for Humans/browser policy." >&2
  exit 1
fi

APP_FQDN="${APP_SUBDOMAIN}.${APP_DOMAIN}"

cf_api() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  if [ -n "$data" ]; then
    curl -sS -X "$method" "https://api.cloudflare.com/client/v4${path}" \
      -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      -H "Content-Type: application/json" \
      --data "$data"
  else
    curl -sS -X "$method" "https://api.cloudflare.com/client/v4${path}" \
      -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}"
  fi
}

ensure_success() {
  local resp="$1"
  if ! echo "$resp" | jq -e '.success == true' >/dev/null 2>&1; then
    echo "Cloudflare API error:" >&2
    echo "$resp" | jq '.' >&2 || echo "$resp" >&2
    exit 1
  fi
}

get_first_id_by_name() {
  local resp="$1"
  local name="$2"
  echo "$resp" | jq -r --arg name "$name" '.result[] | select(.name == $name) | .id' | head -n 1
}

echo "==> Step 1: Create tunnel + ingress config + DNS record"

TUNNEL_ID="${TUNNEL_ID:-}"
TUNNEL_TOKEN="${TUNNEL_TOKEN:-}"

if [ -z "$TUNNEL_ID" ]; then
  tunnel_list="$(cf_api GET "/accounts/${CLOUDFLARE_ACCOUNT_ID}/cfd_tunnel")"
  ensure_success "$tunnel_list"
  TUNNEL_ID="$(get_first_id_by_name "$tunnel_list" "$TUNNEL_NAME")"
fi

if [ -z "$TUNNEL_ID" ]; then
  tunnel_payload="$(jq -n --arg name "$TUNNEL_NAME" '{name: $name, config_src: "cloudflare"}')"
  tunnel_resp="$(cf_api POST "/accounts/${CLOUDFLARE_ACCOUNT_ID}/cfd_tunnel" "$tunnel_payload")"
  ensure_success "$tunnel_resp"
  TUNNEL_ID="$(echo "$tunnel_resp" | jq -r '.result.id')"
  TUNNEL_TOKEN="$(echo "$tunnel_resp" | jq -r '.result.token')"
fi

if [ -z "$TUNNEL_TOKEN" ]; then
  tunnel_resp="$(cf_api GET "/accounts/${CLOUDFLARE_ACCOUNT_ID}/cfd_tunnel/${TUNNEL_ID}")"
  ensure_success "$tunnel_resp"
  TUNNEL_TOKEN="$(echo "$tunnel_resp" | jq -r '.result.token // empty')"
fi

if [ -z "$TUNNEL_TOKEN" ]; then
  echo "Could not retrieve tunnel token. Set TUNNEL_TOKEN manually." >&2
  exit 1
fi

if [ -z "$ENV_TEMPLATE_PATH" ]; then
  if [ -f "${ENV_FILE_PATH}.example" ]; then
    ENV_TEMPLATE_PATH="${ENV_FILE_PATH}.example"
  elif [ -f "${repo_root}/.env.example" ]; then
    ENV_TEMPLATE_PATH="${repo_root}/.env.example"
  fi
fi

mkdir -p "$(dirname "$ENV_FILE_PATH")"
if [ ! -f "$ENV_FILE_PATH" ]; then
  if [ -n "$ENV_TEMPLATE_PATH" ] && [ -f "$ENV_TEMPLATE_PATH" ]; then
    cp "$ENV_TEMPLATE_PATH" "$ENV_FILE_PATH"
  else
    touch "$ENV_FILE_PATH"
  fi
fi

tmp_env="$(mktemp)"
awk -v token="$TUNNEL_TOKEN" '
  BEGIN { found = 0 }
  /^CLOUDFLARE_TUNNEL_TOKEN=/ {
    print "CLOUDFLARE_TUNNEL_TOKEN=" token
    found = 1
    next
  }
  { print }
  END {
    if (!found) {
      print "CLOUDFLARE_TUNNEL_TOKEN=" token
    }
  }
' "$ENV_FILE_PATH" > "$tmp_env"
mv "$tmp_env" "$ENV_FILE_PATH"
echo "Updated ${ENV_FILE_PATH} with CLOUDFLARE_TUNNEL_TOKEN"

ingress_payload="$(jq -n \
  --arg hostname "$APP_FQDN" \
  --arg service "$ORIGIN_SERVICE" \
  '{config: {ingress: [{hostname: $hostname, service: $service}, {service: "http_status:404"}]}}')"

ingress_resp="$(cf_api PUT "/accounts/${CLOUDFLARE_ACCOUNT_ID}/cfd_tunnel/${TUNNEL_ID}/configurations" "$ingress_payload")"
ensure_success "$ingress_resp"

dns_payload="$(jq -n \
  --arg type "CNAME" \
  --arg name "$APP_SUBDOMAIN" \
  --arg content "${TUNNEL_ID}.cfargotunnel.com" \
  '{type: $type, name: $name, content: $content, proxied: true}')"

dns_resp="$(cf_api POST "/zones/${CLOUDFLARE_ZONE_ID}/dns_records" "$dns_payload")"
if ! echo "$dns_resp" | jq -e '.success == true' >/dev/null 2>&1; then
  echo "DNS record creation failed (it may already exist). Response:" >&2
  echo "$dns_resp" | jq '.' >&2 || echo "$dns_resp" >&2
fi

echo "==> Step 2: Create service token"

service_tokens_resp="$(cf_api GET "/accounts/${CLOUDFLARE_ACCOUNT_ID}/access/service_tokens")"
ensure_success "$service_tokens_resp"

SERVICE_TOKEN_ID="$(get_first_id_by_name "$service_tokens_resp" "$SERVICE_TOKEN_NAME")"
SERVICE_TOKEN_CLIENT_ID=""
SERVICE_TOKEN_CLIENT_SECRET=""

if [ -z "$SERVICE_TOKEN_ID" ]; then
  if [ -n "$SERVICE_TOKEN_DURATION" ]; then
    service_token_payload="$(jq -n \
      --arg name "$SERVICE_TOKEN_NAME" \
      --arg duration "$SERVICE_TOKEN_DURATION" \
      '{name: $name, duration: $duration}')"
  else
    service_token_payload="$(jq -n --arg name "$SERVICE_TOKEN_NAME" '{name: $name}')"
  fi
  service_token_resp="$(cf_api POST "/accounts/${CLOUDFLARE_ACCOUNT_ID}/access/service_tokens" "$service_token_payload")"
  ensure_success "$service_token_resp"
  SERVICE_TOKEN_ID="$(echo "$service_token_resp" | jq -r '.result.id')"
  SERVICE_TOKEN_CLIENT_ID="$(echo "$service_token_resp" | jq -r '.result.client_id')"
  SERVICE_TOKEN_CLIENT_SECRET="$(echo "$service_token_resp" | jq -r '.result.client_secret')"
else
  echo "Service token already exists: ${SERVICE_TOKEN_NAME}"
fi

echo "==> Step 3: Enable One-time PIN identity provider"

idp_list_resp="$(cf_api GET "/accounts/${CLOUDFLARE_ACCOUNT_ID}/access/identity_providers")"
ensure_success "$idp_list_resp"
existing_otp_idp="$(echo "$idp_list_resp" | jq -r '.result[] | select(.type == "onetimepin") | .id' | head -n 1)"

if [ -z "$existing_otp_idp" ]; then
  otp_payload="$(jq -n '{type: "onetimepin", config: {}}')"
  otp_resp="$(cf_api POST "/accounts/${CLOUDFLARE_ACCOUNT_ID}/access/identity_providers" "$otp_payload")"
  ensure_success "$otp_resp"
else
  echo "One-time PIN identity provider already enabled."
fi

echo "==> Step 4: Create Access application + policies"

apps_resp="$(cf_api GET "/accounts/${CLOUDFLARE_ACCOUNT_ID}/access/apps")"
ensure_success "$apps_resp"
ACCESS_APP_ID="$(echo "$apps_resp" | jq -r --arg domain "$APP_FQDN" '.result[] | select(.domain == $domain) | .id' | head -n 1)"

if [ -z "$ACCESS_APP_ID" ]; then
  app_payload="$(jq -n \
    --arg name "$ACCESS_APP_NAME" \
    --arg domain "$APP_FQDN" \
    --arg session_duration "$ACCESS_SESSION_DURATION" \
    '{name: $name, domain: $domain, type: "self_hosted", session_duration: $session_duration, service_auth_401_redirect: true}')"
  app_resp="$(cf_api POST "/accounts/${CLOUDFLARE_ACCOUNT_ID}/access/apps" "$app_payload")"
  ensure_success "$app_resp"
  ACCESS_APP_ID="$(echo "$app_resp" | jq -r '.result.id')"
fi

policies_resp="$(cf_api GET "/accounts/${CLOUDFLARE_ACCOUNT_ID}/access/apps/${ACCESS_APP_ID}/policies")"
ensure_success "$policies_resp"

humans_policy_id="$(get_first_id_by_name "$policies_resp" "Humans/browser")"
jobs_policy_id="$(get_first_id_by_name "$policies_resp" "Jobs/non-interactive")"

if [ -z "$humans_policy_id" ]; then
  include_rules=()
  if [ -n "$ALLOWED_EMAIL_DOMAIN" ]; then
    include_rules+=("$(jq -n --arg domain "$ALLOWED_EMAIL_DOMAIN" '{email_domain: {domain: $domain}}')")
  fi
  if [ -n "$ALLOWED_EMAILS" ]; then
    IFS=',' read -r -a email_list <<< "$ALLOWED_EMAILS"
    for email in "${email_list[@]}"; do
      email_trimmed="$(echo "$email" | xargs)"
      [ -z "$email_trimmed" ] && continue
      include_rules+=("$(jq -n --arg email "$email_trimmed" '{email: {email: $email}}')")
    done
  fi

  include_json="$(printf '%s\n' "${include_rules[@]}" | jq -s '.')"
  humans_policy_payload="$(jq -n \
    --arg name "Humans/browser" \
    --argjson include "$include_json" \
    '{name: $name, decision: "allow", include: $include, exclude: [], require: []}')"

  humans_policy_resp="$(cf_api POST "/accounts/${CLOUDFLARE_ACCOUNT_ID}/access/apps/${ACCESS_APP_ID}/policies" "$humans_policy_payload")"
  ensure_success "$humans_policy_resp"
fi

if [ -z "$jobs_policy_id" ]; then
  if [ -z "$SERVICE_TOKEN_ID" ]; then
    echo "Missing SERVICE_TOKEN_ID for Jobs/non-interactive policy." >&2
    exit 1
  fi
  # Cloudflare expects service_token.token_id in Access policy rules
  jobs_include="$(jq -n --arg id "$SERVICE_TOKEN_ID" '{service_token: {token_id: $id}}')"
  jobs_policy_payload="$(jq -n \
    --arg name "Jobs/non-interactive" \
    --argjson include "[${jobs_include}]" \
    '{name: $name, decision: "non_identity", include: $include, exclude: [], require: []}')"

  jobs_policy_resp="$(cf_api POST "/accounts/${CLOUDFLARE_ACCOUNT_ID}/access/apps/${ACCESS_APP_ID}/policies" "$jobs_policy_payload")"
  ensure_success "$jobs_policy_resp"
fi

cat <<EOF
==> Done

Tunnel:
  TUNNEL_ID=${TUNNEL_ID}
  TUNNEL_TOKEN=${TUNNEL_TOKEN}

Access app:
  ACCESS_APP_ID=${ACCESS_APP_ID}
  APP_FQDN=${APP_FQDN}

Service token (save these once; they are only returned on creation):
  SERVICE_TOKEN_ID=${SERVICE_TOKEN_ID}
  SERVICE_TOKEN_CLIENT_ID=${SERVICE_TOKEN_CLIENT_ID}
  SERVICE_TOKEN_CLIENT_SECRET=${SERVICE_TOKEN_CLIENT_SECRET}
EOF
