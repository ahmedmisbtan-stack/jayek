#!/usr/bin/env bash
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:3000}"
for path in /health /health/ready /api/v1/integrations/status; do
  code=$(curl -sS -o /tmp/jayek-smoke.out -w '%{http_code}' "$BASE_URL$path")
  echo "$path -> $code"
  test "$code" = "200"
done
