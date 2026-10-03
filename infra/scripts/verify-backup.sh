#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?DATABASE_URL is required}"
backup="${1:?Usage: verify-backup.sh /path/to/backup.dump}"
test -f "$backup"
pg_restore --list "$backup" >/tmp/jayek-backup-list.txt
# Require core application tables to be present in the archive.
for table in users orders order_items deliveries; do
  grep -Eq "TABLE .* public ${table} " /tmp/jayek-backup-list.txt || { echo "Missing table in backup: $table"; exit 1; }
done
echo "Backup archive is readable and contains core JAYEK tables: $backup"
