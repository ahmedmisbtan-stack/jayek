#!/usr/bin/env bash
set -euo pipefail
EXPECTED="gayk-62a6e"
ACTUAL="${FIREBASE_PROJECT_ID:-$EXPECTED}"
if [[ "$ACTUAL" != "$EXPECTED" ]]; then
  echo "Firebase project mismatch: expected $EXPECTED, got $ACTUAL" >&2
  exit 1
fi
if [[ -f "firebase.json" && -f ".firebaserc" ]]; then
  grep -q 'gayk-62a6e' .firebaserc
else
  echo "Firebase config files are missing" >&2
  exit 1
fi
if find . -type f \( -name 'service-account*.json' -o -name '*firebase-adminsdk*.json' \) -not -path './node_modules/*' | grep -q .; then
  echo "Private Firebase credential file detected in source tree" >&2
  exit 1
fi
echo "Firebase project gate: PASS ($EXPECTED)"
