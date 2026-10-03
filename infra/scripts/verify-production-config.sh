#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
FILE="${1:-.env.production}"
[[ -f "$FILE" ]] || { echo "Missing $FILE" >&2; exit 1; }

fail=0
for key in POSTGRES_PASSWORD DATABASE_URL JWT_SECRET; do
  value="$(grep -E "^${key}=" "$FILE" | tail -1 | cut -d= -f2- || true)"
  if [[ -z "$value" || "$value" == *CHANGE_ME* || "$value" == *YOUR-* ]]; then
    echo "FAIL $key"
    fail=1
  else
    echo "OK   $key"
  fi
done

if grep -Eq '^ALLOW_DEV_HEADERS=true$' "$FILE"; then
  echo "FAIL ALLOW_DEV_HEADERS must be false in production"; fail=1
else
  echo "OK   ALLOW_DEV_HEADERS"
fi

docker compose --env-file "$FILE" -f docker-compose.production.yml config >/dev/null && echo "OK   compose config" || { echo "FAIL compose config"; fail=1; }
exit "$fail"
