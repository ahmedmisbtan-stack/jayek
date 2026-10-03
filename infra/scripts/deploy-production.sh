#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f .env.production ]]; then
  echo "ERROR: infra/.env.production is missing. Copy .env.production.example and fill real secrets." >&2
  exit 1
fi

required=(POSTGRES_PASSWORD DATABASE_URL JWT_SECRET)
for key in "${required[@]}"; do
  value="$(grep -E "^${key}=" .env.production | tail -1 | cut -d= -f2- || true)"
  if [[ -z "$value" || "$value" == *CHANGE_ME* ]]; then
    echo "ERROR: ${key} is missing or still uses a placeholder." >&2
    exit 1
  fi
done

docker compose --env-file .env.production -f docker-compose.production.yml config >/dev/null
docker compose --env-file .env.production -f docker-compose.production.yml up -d --build

for i in {1..30}; do
  if curl -fsS "http://127.0.0.1:${API_PORT:-3000}/api/v1/health/ready" >/dev/null; then
    echo "JAYEK production deployment is READY."
    exit 0
  fi
  sleep 2
done

echo "ERROR: API did not become ready within 60 seconds." >&2
docker compose --env-file .env.production -f docker-compose.production.yml ps || true
exit 1
