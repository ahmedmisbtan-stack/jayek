#!/usr/bin/env bash
set -euo pipefail
JWT="$(openssl rand -base64 48 | tr -d '\n')"
DB="$(openssl rand -base64 36 | tr -d '\n' | tr '/+' '_-')"
WEBHOOK="$(openssl rand -hex 32)"
cat <<EOF
# Paste these into infra/.env.production; never commit this output.
POSTGRES_PASSWORD=$DB
DATABASE_URL=postgresql://jayek:$DB@postgres:5432/jayek
JWT_SECRET=$JWT
PAYMENT_WEBHOOK_SECRET=$WEBHOOK
EOF
