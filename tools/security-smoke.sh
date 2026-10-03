#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:3000/api/v1}"
CUSTOMER_PHONE="${CUSTOMER_PHONE:-01000000004}"
SECOND_CUSTOMER_PHONE="${SECOND_CUSTOMER_PHONE:-01000000005}"
ADMIN_PHONE="${ADMIN_PHONE:-01000000001}"
MERCHANT_PHONE="${MERCHANT_PHONE:-01000000002}"
RIDER_PHONE="${RIDER_PHONE:-01000000003}"

fail(){ echo "SECURITY_SMOKE_FAIL: $*" >&2; exit 1; }
req(){ curl -sS --fail-with-body "$@"; }
status(){ curl -sS -o /tmp/jayek-response.json -w '%{http_code}' "$@"; }
expect_status(){ local expected="$1"; shift; local actual; actual="$(status "$@")"; if [[ "$actual" != "$expected" ]]; then cat /tmp/jayek-response.json >&2 || true; fail "expected HTTP $expected, got $actual"; fi; }
json(){ jq -r "$1" /tmp/jayek-response.json; }
otp_login(){
  local phone="$1" name="$2"
  curl -sS -X POST "$BASE_URL/auth/request-otp" -H 'content-type: application/json' --data-binary "$(jq -nc --arg p "$phone" '{phone:$p}')" > /tmp/jayek-response.json
  local challenge code
  challenge="$(json '.challengeId')"; code="$(json '.devCode')"
  [[ "$challenge" != "null" && "$code" != "null" ]] || fail "OTP challenge/code missing for $phone"
  curl -sS -X POST "$BASE_URL/auth/verify-otp" -H 'content-type: application/json' --data-binary "$(jq -nc --arg c "$challenge" --arg p "$phone" --arg code "$code" --arg n "$name" '{challengeId:$c,phone:$p,code:$code,name:$n}')" > /tmp/jayek-response.json
  local token; token="$(json '.accessToken')"
  [[ "$token" != "null" && -n "$token" ]] || fail "access token missing for $phone"
  printf '%s' "$token"
}

expect_status 200 "$BASE_URL/health"
expect_status 400 "$BASE_URL/auth/request-otp" -X POST -H 'content-type: application/json' --data '{"phone":"010"}'

customer_token="$(otp_login "$CUSTOMER_PHONE" "Security Test Customer")"
second_customer_token="$(otp_login "$SECOND_CUSTOMER_PHONE" "Second Security Customer")"
admin_token="$(otp_login "$ADMIN_PHONE" "Security Test Admin")"
merchant_token="$(otp_login "$MERCHANT_PHONE" "Security Test Merchant")"
rider_token="$(otp_login "$RIDER_PHONE" "Security Test Rider")"

expect_status 401 "$BASE_URL/admin/metrics" -H "Authorization: Bearer $customer_token"
expect_status 401 "$BASE_URL/integrations/status" -H "Authorization: Bearer $customer_token"
expect_status 200 "$BASE_URL/admin/metrics" -H "Authorization: Bearer $admin_token"

expect_status 400 "$BASE_URL/addresses" -X POST -H 'content-type: application/json' -H "Authorization: Bearer $customer_token" --data '{"village":"الديسمي","latitude":999,"longitude":999}'
expect_status 401 "$BASE_URL/rider/location" -X PATCH -H 'content-type: application/json' -H "Authorization: Bearer $customer_token" --data '{"latitude":29.6465,"longitude":31.3185}'

home="$(req "$BASE_URL/home?village=%D8%A7%D9%84%D8%AF%D9%8A%D8%B3%D9%85%D9%8A")"
merchant_id="$(jq -r '.merchants[0].id' <<<"$home")"
product_id="$(jq -r '.popular[0].id' <<<"$home")"
[[ "$merchant_id" != "null" && "$product_id" != "null" ]] || fail "seed catalog missing"

curl -sS -X POST "$BASE_URL/addresses" -H 'content-type: application/json' -H "Authorization: Bearer $customer_token" --data "$(jq -nc '{village:"الديسمي",label:"البيت",details:"اختبار أمني",latitude:29.6465,longitude:31.3185,isDefault:true}')" > /tmp/jayek-response.json
address_id="$(json '.id')"
[[ "$address_id" != "null" ]] || fail "address creation failed"

order_body="$(jq -nc --arg m "$merchant_id" --arg p "$product_id" --arg a "$address_id" '{merchantId:$m,items:[{productId:$p,quantity:1}],addressId:$a}')"
idem="security-idempotency-$(date +%s%N)"
curl -sS -X POST "$BASE_URL/orders" -H 'content-type: application/json' -H "Authorization: Bearer $customer_token" -H "Idempotency-Key: $idem" --data "$order_body" > /tmp/jayek-response.json
order_id="$(json '.id')"
[[ "$order_id" != "null" ]] || fail "order creation failed"

expect_status 200 "$BASE_URL/orders/$order_id" -H "Authorization: Bearer $customer_token"
expect_status 404 "$BASE_URL/orders/$order_id" -H "Authorization: Bearer $second_customer_token"

# IDOR regression: another user must not be able to reuse the first user's idempotency key.
expect_status 409 "$BASE_URL/orders" -X POST -H 'content-type: application/json' -H "Authorization: Bearer $second_customer_token" -H "Idempotency-Key: $idem" --data "$order_body"

# Merchant ownership and state machine.
expect_status 200 "$BASE_URL/merchant/orders/$merchant_id" -H "Authorization: Bearer $merchant_token"
expect_status 401 "$BASE_URL/merchant/orders/$merchant_id" -H "Authorization: Bearer $customer_token"

# COD-only pilot: online methods are rejected rather than creating fake paid intents.
expect_status 400 "$BASE_URL/payments/intent" -X POST -H 'content-type: application/json' -H "Authorization: Bearer $customer_token" --data "$(jq -nc --arg o "$order_id" '{orderId:$o,method:"CARD"}')"

# Activate rider and verify invalid GPS is rejected.
expect_status 200 "$BASE_URL/rider/online" -X PATCH -H 'content-type: application/json' -H "Authorization: Bearer $rider_token" --data '{"online":true}'
expect_status 400 "$BASE_URL/rider/location" -X PATCH -H 'content-type: application/json' -H "Authorization: Bearer $rider_token" --data '{"latitude":999,"longitude":999}'

echo "SECURITY_SMOKE_OK"
