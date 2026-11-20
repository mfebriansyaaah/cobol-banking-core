#!/usr/bin/env bash
# Fail when the live schema (database/schema.sql + database/migrations/*)
# differs from the committed snapshots (database/schema_full.sql and the
# gzipped immutable baseline database/schema_v2.sql.gz, which must be
# byte-identical bodies). A diff means either schema.sql changed without a
# corresponding migration, or an applied migration file was edited (which
# database/migrate.sh --check also catches via checksums). Regenerate
# deliberately after reviewing the diff:
#   bash scripts/generate_schema_snapshot.sh [--out <file>]
#
# --from reuses an already-generated normalized snapshot (CI: the
# db-snapshot producer emits it from the same migrated database) instead of
# provisioning a throwaway database again.
#
# Usage: bash scripts/check_schema_drift.sh [--from <file>]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FROM=""
while [ $# -gt 0 ]; do
    case "$1" in
        --from)
            [ -n "${2:-}" ] || { echo "usage: $0 [--from <file>]" >&2; exit 2; }
            FROM="$2"
            shift 2
            ;;
        *)
            echo "unknown argument: $1" >&2
            echo "usage: $0 [--from <file>]" >&2
            exit 2
            ;;
    esac
done

owns_tmp=0
if [ -n "$FROM" ]; then
    [ -f "$FROM" ] || { echo "FAIL: snapshot not found: $FROM" >&2; exit 1; }
    tmp="$FROM"
else
    tmp="$(mktemp "${TMPDIR:-/tmp}/schema-drift.XXXXXX.sql")"
    owns_tmp=1
    bash "$ROOT/scripts/generate_schema_snapshot.sh" --out "$tmp" > /dev/null
fi
diff_file="$(mktemp "${TMPDIR:-/tmp}/schema-drift-diff.XXXXXX")"
cleanup() {
    rm -f "$diff_file"
    if [ "$owns_tmp" = "1" ]; then
        rm -f "$tmp"
    fi
}
trap cleanup EXIT

failed=0
for ref in database/schema_full.sql database/schema_v2.sql.gz; do
    if [ ! -f "$ref" ]; then
        echo "FAIL: missing $ref" >&2
        failed=1
        continue
    fi
    if [ "$ref" = "database/schema_v2.sql.gz" ]; then
        diff -u <(gzip -dc "$ref") "$tmp" > "$diff_file" || true
    else
        diff -u "$ref" "$tmp" > "$diff_file" || true
    fi
    if [ ! -s "$diff_file" ]; then
        echo "OK: schema matches $ref"
        rm -f "$diff_file"
    else
        echo "FAIL: schema drift detected (fresh build differs from $ref):"
        head -40 "$diff_file"
        rm -f "$diff_file"
        echo "hint: if the change is intentional, review it and regenerate with bash scripts/generate_schema_snapshot.sh"
        failed=1
    fi
done
[ "$failed" = "0" ] || exit 1
