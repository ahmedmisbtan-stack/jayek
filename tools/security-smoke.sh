#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:3000/api/v1}"
CUSTOMER_PHONE="${CUSTOMER_PHONE:-01000000004}"
ADMIN_PHONE="${ADMIN_PHONE:-01000000001}"

fail() { echo "SECURITY_SMOKE_FAIL: $*" >&2; exit 1; }
expect_status() {
  local expected="$1"; shift
  local actual
  actual="$(curl -sS -o /tmp/jayek-response.json -w '%{http_code}' "$@")"
  if [[ "$actual" != "$expected" ]]; then
    cat /tmp/jayek-response.json >&2 || true
    fail "expected HTTP $expected, got $actual"
  fi
}

json_field() { jq -r "$1" /tmp/jayek-response.json; }

expect_status 200 "$BASE_URL/health"

curl -sS -X POST "$BASE_URL/auth/request-otp" -H 'content-type: application/json'   -d "{"phone":"$CUSTOMER_PHONE"}" > /tmp/jayek-response.json
challenge="$(json_field '.challengeId')"
code="$(json_field '.devCode')"
[[ "$challenge" != "null" && "$code" != "null" ]] || fail "customer OTP challenge/code missing"

curl -sS -X POST "$BASE_URL/auth/verify-otp" -H 'content-type: application/json'   -d "{"challengeId":"$challenge","phone":"$CUSTOMER_PHONE","code":"$code","name":"Security Test Customer"}" > /tmp/jayek-response.json
customer_token="$(json_field '.accessToken')"
[[ "$customer_token" != "null" ]] || fail "customer token missing"

expect_status 401 "$BASE_URL/admin/metrics" -H "Authorization: Bearer $customer_token"
expect_status 401 "$BASE_URL/integrations/status" -H "Authorization: Bearer $customer_token"

curl -sS -X POST "$BASE_URL/auth/request-otp" -H 'content-type: application/json'   -d "{"phone":"$ADMIN_PHONE"}" > /tmp/jayek-response.json
admin_challenge="$(json_field '.challengeId')"
admin_code="$(json_field '.devCode')"
[[ "$admin_challenge" != "null" && "$admin_code" != "null" ]] || fail "admin OTP challenge/code missing"

curl -sS -X POST "$BASE_URL/auth/verify-otp" -H 'content-type: application/json'   -d "{"challengeId":"$admin_challenge","phone":"$ADMIN_PHONE","code":"$admin_code","name":"Security Test Admin"}" > /tmp/jayek-response.json
admin_token="$(json_field '.accessToken')"
[[ "$admin_token" != "null" ]] || fail "admin token missing"

expect_status 200 "$BASE_URL/admin/metrics" -H "Authorization: Bearer $admin_token"

expect_status 401 "$BASE_URL/rider/location" -X PATCH -H 'content-type: application/json'   -H "Authorization: Bearer $customer_token" -d '{"latitude":29.6465,"longitude":31.3185}'
expect_status 401 "$BASE_URL/rider/location" -X PATCH -H 'content-type: application/json'   -H "Authorization: Bearer $admin_token" -d '{"latitude":999,"longitude":999}'

expect_status 401 "$BASE_URL/orders/00000000-0000-4000-8000-000000000001"
expect_status 401 "$BASE_URL/support/tickets" -X POST -H 'content-type: application/json'   -d '{"subject":"x","message":"x"}'

echo "SECURITY_SMOKE_OK"
