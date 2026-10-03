#!/usr/bin/env bash
set -euo pipefail
BASE="${JAYEK_API_URL:-http://127.0.0.1:3000/api/v1}"
curl -fsS "$BASE/health" >/tmp/jayek-health.json
curl -fsS "$BASE/health/ready" >/tmp/jayek-ready.json
python3 - <<'PY2'
import json
for f in ['/tmp/jayek-health.json','/tmp/jayek-ready.json']:
 d=json.load(open(f)); assert d.get('status') in ('ok','ready'); print(f,d.get('status'))
PY2
echo 'PILOT_INFRA_GATE=PASS'
echo 'Manual gate: real OTP -> real order -> merchant -> rider -> delivery -> notification -> review -> backup -> restore.'
