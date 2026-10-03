#!/usr/bin/env bash
set -euo pipefail
file="${1:-infra/.env.production.example}"
test -f "$file"
required=(NODE_ENV PORT DATABASE_URL JWT_SECRET OTP_PROVIDER PUSH_PROVIDER MAP_PROVIDER PAYMENT_PROVIDER STORAGE_PROVIDER)
for key in "${required[@]}"; do
  grep -q "^${key}=" "$file" || { echo "Missing $key in $file"; exit 1; }
done
echo "Config template OK: $file"
