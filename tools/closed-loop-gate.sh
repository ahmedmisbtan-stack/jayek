#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "GATE FAILED: $1" >&2; exit 1; }
python3 - "$ROOT" <<'PY'
import json,re,sys
from pathlib import Path
root=Path(sys.argv[1])
p=json.loads((root/'apps/api/package.json').read_text())
if p['version']!='3.3.0': raise SystemExit('API package version mismatch')
d=(root/'apps/api/src/domain.ts').read_text()
if "API_VERSION = '3.3.0'" not in d: raise SystemExit('domain version mismatch')
for f in ['apps/mobile/pubspec.yaml','apps/rider/pubspec.yaml']:
 s=(root/f).read_text()
 if 'version: 3.3.0+12' not in s: raise SystemExit(f+' version mismatch')
main=(root/'apps/api/src/main.ts').read_text()
if "JWT_SECRET = process.env.JWT_SECRET || ''" not in main: raise SystemExit('production JWT gate missing')
if 'app.enableCors({origin:(origin,cb)=>' not in main: raise SystemExit('CORS allow-list missing')
schema=(root/'infra/schema.sql').read_text()
for needle in ['support_ticket_messages','order_stock_reservations','uq_notifications_user_event']:
 if needle not in schema: raise SystemExit('schema missing '+needle)
for f in ['.env.example','infra/.env.production.example','infra/.env.staging.example']:
 if not (root/f).exists(): raise SystemExit(f+' missing')
 if 'CORS_ORIGINS=' not in (root/f).read_text(): raise SystemExit(f+' missing CORS_ORIGINS')
print('CLOSED_LOOP_GATE=PASS')
PY
echo "CLOSED_LOOP_GATE=PASS"
