#!/usr/bin/env bash
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:3000}"
expect_json="${EXPECT_VERSION:-2.0.0}"
health="$(curl -fsS "$BASE_URL/api/v1/health")"
ready="$(curl -fsS "$BASE_URL/api/v1/health/ready")"
node -e 'const x=JSON.parse(process.argv[1]); if(x.status!=="ok"||x.version!==process.argv[2]) process.exit(1)' "$health" "$expect_json"
node -e 'const x=JSON.parse(process.argv[1]); if(x.status!=="ready"||x.database!=="ok") process.exit(1)' "$ready"
echo "JAYEK pilot smoke OK: version=$expect_json"
