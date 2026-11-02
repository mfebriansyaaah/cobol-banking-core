#!/usr/bin/env bash
# Fail when the live schema (database/schema.sql + database/migrations/*)
# differs from the committed database/schema_full.sql. A diff means either
# schema.sql changed without a corresponding migration, or an applied
# migration file was edited (which database/migrate.sh --check also catches
# via checksums). Regenerate deliberately after reviewing the diff:
#   bash scripts/generate_schema_snapshot.sh
# Usage: bash scripts/check_schema_drift.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SNAPSHOT="database/schema_full.sql"
[ -f "$SNAPSHOT" ] || { echo "FAIL: missing $SNAPSHOT (run bash scripts/generate_schema_snapshot.sh)" >&2; exit 2; }

tmp="$(mktemp "${TMPDIR:-/tmp}/schema-drift.XXXXXX.sql")"
trap 'rm -f "$tmp"' EXIT
bash "$ROOT/scripts/generate_schema_snapshot.sh" --out "$tmp" > /dev/null

if diff -u "$SNAPSHOT" "$tmp" > "$tmp.diff"; then
    echo "OK: schema matches $SNAPSHOT"
    rm -f "$tmp.diff"
    exit 0
fi
echo "FAIL: schema drift detected (fresh build differs from $SNAPSHOT):"
head -40 "$tmp.diff"
rm -f "$tmp.diff"
echo "hint: if the change is intentional, review it and regenerate with bash scripts/generate_schema_snapshot.sh"
exit 1
