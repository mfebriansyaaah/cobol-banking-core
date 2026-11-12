#!/usr/bin/env bash
# Fail when the live schema (database/schema.sql + database/migrations/*)
# differs from the committed snapshots (database/schema_full.sql and
# database/schema_v2.sql, which must be byte-identical bodies). A diff means
# either schema.sql changed without a corresponding migration, or an applied
# migration file was edited (which database/migrate.sh --check also catches
# via checksums). Regenerate deliberately after reviewing the diff:
#   bash scripts/generate_schema_snapshot.sh [--out <file>]
# Usage: bash scripts/check_schema_drift.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

tmp="$(mktemp "${TMPDIR:-/tmp}/schema-drift.XXXXXX.sql")"
trap 'rm -f "$tmp" "$tmp.diff"' EXIT
bash "$ROOT/scripts/generate_schema_snapshot.sh" --out "$tmp" > /dev/null

failed=0
for ref in database/schema_full.sql database/schema_v2.sql; do
    if [ ! -f "$ref" ]; then
        echo "FAIL: missing $ref" >&2
        failed=1
        continue
    fi
    if diff -u "$ref" "$tmp" > "$tmp.diff"; then
        echo "OK: schema matches $ref"
        rm -f "$tmp.diff"
    else
        echo "FAIL: schema drift detected (fresh build differs from $ref):"
        head -40 "$tmp.diff"
        rm -f "$tmp.diff"
        echo "hint: if the change is intentional, review it and regenerate with bash scripts/generate_schema_snapshot.sh"
        failed=1
    fi
done
[ "$failed" = "0" ] || exit 1
