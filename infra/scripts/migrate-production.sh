#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ -f .env.production ]] || { echo 'Missing infra/.env.production' >&2; exit 2; }
command -v docker >/dev/null || { echo 'Docker is required' >&2; exit 3; }
set -a
# shellcheck disable=SC1091
source .env.production
set +a
: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${POSTGRES_DB:?POSTGRES_DB is required}"
docker compose --env-file .env.production -f docker-compose.production.yml exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "CREATE TABLE IF NOT EXISTS schema_migrations (filename TEXT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT now());"
for file in migrations/*.sql; do
  [ -e "$file" ] || continue
  name="$(basename "$file")"
  applied="$(docker compose --env-file .env.production -f docker-compose.production.yml exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "SELECT 1 FROM schema_migrations WHERE filename='${name}'" | tr -d '\r')"
  if [[ "$applied" == '1' ]]; then echo "SKIP $name"; continue; fi
  echo "APPLY $name"
  docker compose --env-file .env.production -f docker-compose.production.yml exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 < "$file"
  docker compose --env-file .env.production -f docker-compose.production.yml exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "INSERT INTO schema_migrations(filename) VALUES ('${name}')"
done
echo 'PRODUCTION_MIGRATIONS=OK'
