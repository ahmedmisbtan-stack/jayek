#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${DATABASE_URL:?DATABASE_URL is required}"
command -v psql >/dev/null || { echo 'psql is required' >&2; exit 1; }
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "CREATE TABLE IF NOT EXISTS schema_migrations (filename TEXT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT now());"
for file in "$ROOT"/migrations/*.sql; do
  [ -e "$file" ] || continue
  name="$(basename "$file")"
  if psql "$DATABASE_URL" -Atqc "SELECT 1 FROM schema_migrations WHERE filename='${name}'" | grep -q 1; then
    echo "SKIP $name"
    continue
  fi
  echo "APPLY $name"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$file"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "INSERT INTO schema_migrations(filename) VALUES ('${name}')"
done
echo 'MIGRATIONS=OK'
