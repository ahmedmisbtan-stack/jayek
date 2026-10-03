#!/usr/bin/env sh
set -eu
: "${DATABASE_URL:?DATABASE_URL is required}"
OUT_DIR="${BACKUP_DIR:-./backups}"
mkdir -p "$OUT_DIR"
STAMP="$(date +%Y%m%d_%H%M%S)"
pg_dump "$DATABASE_URL" --format=custom --file="$OUT_DIR/jayek_${STAMP}.dump"
echo "Backup created: $OUT_DIR/jayek_${STAMP}.dump"
