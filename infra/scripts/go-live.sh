#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ -f .env.production ]] || { echo "Missing infra/.env.production" >&2; exit 2; }
command -v docker >/dev/null || { echo "Docker is required on the deployment host" >&2; exit 3; }
./scripts/verify-production-config.sh
./scripts/verify-integrations.sh
docker compose -f docker-compose.production.yml --env-file .env.production up -d --build
./scripts/deploy-production.sh
./scripts/migrate-production.sh
./scripts/pilot-acceptance.sh
