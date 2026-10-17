#!/bin/bash
# Export one reconciliation run and its findings as CSV (run row, then one
# row per finding) for audit evidence. Prints to stdout.
# Usage: scripts/export_reconciliation.sh <run_id>  (DB_* env as usual)

set -e
cd "$(dirname "$0")/.."

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

run_id="${1:-}"
case "$run_id" in
    ''|*[!0-9]*) echo "usage: $0 <run_id>" >&2; exit 1 ;;
esac

q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }

[ "$(q "SELECT COUNT(*) FROM reconciliation_runs WHERE run_id='$run_id';")" = "1" ] || { echo "unknown run: $run_id" >&2; exit 1; }

echo "section,run_id,trigger,actor,status,mismatches,created_at"
q "SELECT CONCAT('run,', run_id, ',', trigger_src, ',', actor_email, ',', status, ',', mismatch_count, ',', created_at) FROM reconciliation_runs WHERE run_id='$run_id';"
echo "section,finding_id,run_id,account_id,balance,ledger_sum,status,owner,resolution_note,created_at,resolved_at"
q "SELECT CONCAT('finding,', finding_id, ',', run_id, ',', account_id, ',', balance, ',', ledger_sum, ',', status, ',', COALESCE(owner_email,''), ',', COALESCE(resolution_note,''), ',', created_at, ',', COALESCE(resolved_at,'')) FROM reconciliation_findings WHERE run_id='$run_id' ORDER BY finding_id;"
