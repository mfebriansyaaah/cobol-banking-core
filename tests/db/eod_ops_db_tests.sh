#!/usr/bin/env bash
# EOD operations shell coverage: batch jobs (EODJOB_*) and calendar/runs.
set -u
# Batch policy comes from the environment and the COBOL server below inherits
# this process env, so exports must precede db_seed (server start).
export DORMANT_AFTER_DAYS=30
export DORMANT_GRACE_DAYS=1
# Batch jobs run once per business date: fixed far-future date + cleanup
# (rerun-safe without pid-modulo collisions).
JD="2099-01-15"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
require_db

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

db_seed
A="admin@test.com"
db_exec "DELETE FROM eod_job_run WHERE business_date='${JD}';"

# Close any leftover RUNNING run first (rerun-safe; runs are global singletons).
for rid in $(db_query "SELECT id FROM eod_run WHERE status='RUNNING';"); do
    run_cobol "EOD_RUN_CLOSE|${rid}|||||${A}" >/dev/null
done

assert_match "EODJOB_LIST ok" "$(run_cobol "EODJOB_LIST|50|0||||${A}")" "SUCCESS\|"
assert_match "EODJOB_HOLD_EXPIRY ok" "$(run_cobol "EODJOB_HOLD_EXPIRY|${JD}|||||${A}")" "SUCCESS\|"
assert_match "EODJOB_DORMANT_MARK ok" "$(run_cobol "EODJOB_DORMANT_MARK|${JD}|||||${A}")" "SUCCESS\|"
assert_match "EODJOB_DORM_SUSPEND ok" "$(run_cobol "EODJOB_DORM_SUSPEND|${JD}|||||${A}")" "SUCCESS\|"
assert_match "EODJOB_RECON ok" "$(run_cobol "EODJOB_RECON|${JD}|||||${A}")" "SUCCESS\|"
assert_match "EODJOB_STATEMENT ok" "$(run_cobol "EODJOB_STATEMENT|${JD}|${JD}|USD|||${A}")" "SUCCESS\|"
assert_match "EOD_CAL_OPEN ok" "$(run_cobol "EOD_CAL_OPEN|2026-06-01|17:00||||${A}")" "SUCCESS\|"
assert_match "EOD_CAL_LIST ok" "$(run_cobol "EOD_CAL_LIST|50|0||||${A}")" "SUCCESS\|"
assert_match "EOD_RUN_START ok" "$(run_cobol "EOD_RUN_START|2026-06-01|||||${A}")" "SUCCESS\|"
runid="$(db_query "SELECT id FROM eod_run WHERE business_date='2026-06-01' ORDER BY id DESC LIMIT 1;")"
assert_match "run row present" "$runid" "^[0-9]+$"
assert_match "EOD_RUN_STATUS ok" "$(run_cobol "EOD_RUN_STATUS|${runid}|||||${A}")" "SUCCESS\|"
assert_match "EOD_PHASE_SET running" "$(run_cobol "EOD_PHASE_SET|${runid}|FEE|RUNNING|0,0,0||${A}")" "SUCCESS\|"
assert_match "EOD_PHASE_SET ok" "$(run_cobol "EOD_PHASE_SET|${runid}|FEE|COMPLETED|0,0,0||${A}")" "SUCCESS\|"
assert_match "EOD_RUN_LIST ok" "$(run_cobol "EOD_RUN_LIST|50|0||||${A}")" "SUCCESS\|"
assert_match "EOD_RUN_FAIL ok" "$(run_cobol "EOD_RUN_FAIL|${runid}|E999|boom|||${A}")" "SUCCESS\|"
assert_match "run failed" "$(db_query "SELECT status FROM eod_run WHERE id=${runid};")" "^FAILED$"
db_exec "DELETE FROM eod_run WHERE business_date='2026-06-01';"
db_exec "DELETE FROM eod_job_run WHERE business_date='${JD}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
