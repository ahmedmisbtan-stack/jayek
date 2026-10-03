#!/usr/bin/env bash
set -euo pipefail
required=(OTP_PROVIDER PUSH_PROVIDER MAP_PROVIDER STORAGE_PROVIDER PAYMENT_WEBHOOK_SECRET JWT_SECRET)
missing=0
for key in "${required[@]}"; do
  if [[ -z "${!key:-}" || "${!key}" == CHANGE_ME* ]]; then
    echo "MISSING: $key"; missing=1
  else
    echo "OK: $key"
  fi
done
[[ "${OTP_PROVIDER:-}" == "http" && -n "${OTP_HTTP_URL:-}" ]] || { echo "INVALID: OTP HTTP configuration"; missing=1; }
[[ "${PUSH_PROVIDER:-}" == "http" && -n "${PUSH_HTTP_URL:-}" ]] || { echo "INVALID: PUSH HTTP configuration"; missing=1; }
[[ "${MAP_PROVIDER:-}" == "http" && -n "${MAPS_ROUTE_URL:-}" ]] || { echo "INVALID: MAP HTTP configuration"; missing=1; }
[[ "${STORAGE_PROVIDER:-}" == "s3" && -n "${STORAGE_UPLOAD_URL:-}" && -n "${STORAGE_PUBLIC_BASE_URL:-}" ]] || { echo "INVALID: STORAGE S3 configuration"; missing=1; }
if (( missing )); then echo "Integration configuration is NOT ready."; exit 1; fi
echo "Integration configuration is ready."
