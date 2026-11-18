#!/usr/bin/env bash
# Collect failure forensics into one directory (P1-5): tool versions, git
# state, database status, and log tails. Every probe is best-effort (a dead
# database must not fail diagnostics) and NEVER prints secrets: only
# non-sensitive env (hosts, names, users) is recorded, never passwords.
# Usage: bash scripts/ci/collect_diagnostics.sh [out-dir]
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1

OUT="${1:-/tmp/ci-diagnostics}"
mkdir -p "$OUT" || exit 2
SUM="$OUT/summary.txt"
: > "$SUM"

say() { printf '%s\n' "$*" | tee -a "$SUM"; }
section() { say ""; say "=== $1 ==="; }
try() { "$@" >>"$SUM" 2>&1 || say "(unavailable: $*)"; }

section "tool versions"
try bash --version
try node --version
try npm --version
try mysql --version
try cobc --version
try gcc --version
try git --version

section "git state"
try git rev-parse HEAD
try git status --short
try git log --oneline -3

section "environment (non-secret only)"
say "DB_HOST=${DB_HOST:-localhost} DB_PORT=${DB_PORT:-3306} DB_NAME=${DB_NAME:-cobol_db} DB_USER=${DB_USER:-cobol_user}"
say "DB_MIGRATE_USER=${DB_MIGRATE_USER:-cobol_user} ISOLATED_DB=${ISOLATED_DB:-1} SKIP_BUILD=${SKIP_BUILD:-0}"

section "database status"
# Never pass an empty -p (it prompts): only attach the password flag when set.
# stdin is always /dev/null so a prompt can never hang diagnostics.
dbq() {
    local args=(-h "${DB_HOST:-localhost}" -P "${DB_PORT:-3306}" -u "${DB_USER:-cobol_user}")
    [ -n "${DB_PASS:-}" ] && args+=("-p$DB_PASS")
    mysql "${args[@]}" "$@" < /dev/null
}
if dbq -e "SELECT VERSION();" >>"$SUM" 2>&1; then
    try dbq -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME:-cobol_db}';"
    say "table count above (for ${DB_NAME:-cobol_db})"
    try dbq -N -B -e "SELECT COUNT(*) FROM ${DB_NAME:-cobol_db}.schema_migrations;"
    say "schema_migrations row count above"
else
    say "(database unreachable; skipping table counts)"
fi

section "migration ledger state"
DB_NAME="${DB_NAME:-cobol_db}" ./database/migrate.sh --check >>"$SUM" 2>&1 \
    || say "(migrations pending or migrate.sh unavailable)"

section "disk and memory"
try df -h /tmp
try free -m

section "service containers"
if command -v docker >/dev/null 2>&1; then
    try docker ps --format '{{.Names}} {{.Image}} {{.Status}}'
    for container in $(docker ps --format '{{.Names}}' 2>/dev/null | grep -i mariadb || true); do
        say "--- logs $container ---"
        docker logs --tail 100 "$container" >>"$SUM" 2>&1 || say "(unavailable: docker logs $container)"
    done
else
    say "(docker unavailable; skipping service container logs)"
fi

section "report summary"
REPORT_TSV=""
for candidate in artifacts/latest/report.tsv artifacts/report.tsv; do
    if [ -f "$candidate" ]; then
        REPORT_TSV="$candidate"
        break
    fi
done
if [ -n "$REPORT_TSV" ]; then
    REPORT_DIR="$(dirname "$REPORT_TSV")"
    cp -f "$REPORT_TSV" "$OUT/report.tsv" 2>/dev/null || true
    cp -f "$REPORT_DIR/run-all.json" "$OUT/run-all.json" 2>/dev/null || true
    awk -F'\t' 'NR>1 {t++; if ($2 != "pass") {f++; print "NOT-PASS:", $0}} END {print "suites:", t+0, "not-pass:", f+0}' "$REPORT_TSV" >>"$SUM" 2>&1 || true
else
    say "(no artifacts/latest/report.tsv or artifacts/report.tsv)"
fi

section "gateway log tails"
for f in /tmp/gateway_endpoints.log /tmp/gateway_fast.log /tmp/gateway_residue.log /tmp/migration_rollback_drill.log /tmp/backup_restore_drill.log /tmp/gateway.log; do
    if [ -f "$f" ]; then
        say "--- tail $f ---"
        tail -30 "$f" >>"$SUM" 2>&1 || true
    fi
done

echo "diagnostics in $OUT"
