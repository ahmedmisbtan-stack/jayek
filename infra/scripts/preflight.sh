#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail=0
for f in infra/.env.production.example infra/docker-compose.production.yml infra/schema.sql; do
  [ -f "$ROOT/$f" ] && echo "OK   $f" || { echo "FAIL $f"; fail=1; }
done
for f in infra/scripts/migrate.sh infra/scripts/verify-production-config.sh tools/closed-loop-gate.sh; do
  bash -n "$ROOT/$f" && echo "OK   $f syntax" || fail=1
done
python3 - "$ROOT" <<'PY'
import json,sys
from pathlib import Path
r=Path(sys.argv[1]); p=json.loads((r/'apps/api/package.json').read_text())
assert p['version']=='3.1.0'
assert 'migrate' in p['scripts'] and 'preflight' in p['scripts']
main=(r/'apps/api/src/main.ts').read_text()
assert "@Get('health/metrics')" in main
assert "FROM orders WHERE id=$1 AND user_id=$2" in main
print('OK   source gates')
PY
[ "$fail" -eq 0 ] || exit 1
echo PRELIGHT=PASS
