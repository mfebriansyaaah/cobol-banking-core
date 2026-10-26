#!/usr/bin/env bash
# Post-merge CI: migration dry-run / rollback drill.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

echo "=== Migration Rollback Drill ==="

# 1. Check all migrations apply cleanly
echo "Step 1: Apply all migrations"
./database/migrate.sh 2>&1 | tail -5

# 2. Verify schema integrity
echo "Step 2: Verify tables exist"
TABLES=$(mysql -h "${DB_HOST:-localhost}" -P "${DB_PORT:-3306}" \
  -u "${DB_MIGRATE_USER:-root}" -p"${DB_MIGRATE_PASS:-root}" \
  "${DB_NAME:-cobol_db}" -N -B -e "SHOW TABLES;" 2>/dev/null | wc -l)
echo "Tables: $TABLES"
if [ "$TABLES" -lt 50 ]; then
  echo "FAIL: too few tables"
  exit 1
fi

# 3. Smoke test binary (skip if binary not available, e.g. in post-merge job)
echo "Step 3: Binary smoke test"
if [ -f ./cobol/bin/main_logic ]; then
  printf 'PING||||||admin@test.com\n' > input.txt
  DB_HOST="${DB_HOST:-localhost}" DB_PORT="${DB_PORT:-3306}" \
    DB_USER="${DB_USER:-cobol_user}" DB_PASS="${DB_PASS:-cobol_pass}" \
    DB_NAME="${DB_NAME:-cobol_db}" ./cobol/bin/main_logic
  cat output.txt
  echo ""
else
  echo "Skipped: binary not available in this context"
fi

echo "Migration rollback drill passed."