#!/bin/bash
# Export one reconciliation run and its findings as CSV (run row, then one
# row per finding) for audit evidence. Prints to stdout.
# Usage: scripts/export_reconciliation.sh <run_id>  (DB_* env as usual)
#
# Output is RFC 4180 CSV: fields are quoted only when needed and embedded
# quotes are doubled. Values that would be interpreted as spreadsheet
# formulas by Excel/LibreOffice (leading =,+,-,@,tab,CR) are neutralised
# with a leading apostrophe so evidence files cannot carry injected formulas.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

run_id="${1:-}"
case "$run_id" in
    ''|*[!0-9]*) echo "usage: $0 <run_id>" >&2; exit 1 ;;
esac

export DB_USER DB_PASS DB_NAME run_id
exec python3 - <<'PY'
import csv, os, subprocess, sys

db_user = os.environ['DB_USER']
db_pass = os.environ['DB_PASS']
db_name = os.environ['DB_NAME']
run_id = os.environ['run_id']

def mysql(sql):
    proc = subprocess.run(
        ['mysql', '-u', db_user, '-p' + db_pass, db_name, '-N', '-B', '-e', sql],
        capture_output=True, text=True)
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
        sys.exit(1)
    return proc.stdout

# Validate the run exists.
count = mysql("SELECT COUNT(*) FROM reconciliation_runs WHERE run_id='%s';" % run_id).strip()
if count != '1':
    sys.stderr.write('unknown run: %s\n' % run_id)
    sys.exit(1)

DANGEROUS = ('=', '+', '-', '@', '\t', '\r')

def sanitize(value):
    v = '' if value is None else str(value)
    if v and v[0] in DANGEROUS:
        v = "'" + v
    return v

writer = csv.writer(sys.stdout, quoting=csv.QUOTE_MINIMAL, lineterminator='\n')

writer.writerow(['section','run_id','trigger','actor','status','mismatches','created_at'])

# Run row.
rows = mysql(
    "SELECT run_id, trigger_src, actor_email, status, mismatch_count, created_at "
    "FROM reconciliation_runs WHERE run_id='%s';" % run_id).splitlines()
for r in rows:
    cols = r.split('\t')
    writer.writerow(['run'] + [sanitize(c) for c in cols])

# Finding header (printed once, only if there are findings; keep simple: always print).
writer.writerow(['section','finding_id','run_id','account_id','balance','ledger_sum','status','owner','resolution_note','created_at','resolved_at'])

# Finding rows.
frows = mysql(
    "SELECT finding_id, run_id, account_id, balance, ledger_sum, status, "
    "COALESCE(owner_email,''), COALESCE(resolution_note,''), created_at, "
    "COALESCE(resolved_at,'') FROM reconciliation_findings "
    "WHERE run_id='%s' ORDER BY finding_id;" % run_id).splitlines()
for r in frows:
    cols = r.split('\t')
    writer.writerow(['finding'] + [sanitize(c) for c in cols])
PY
