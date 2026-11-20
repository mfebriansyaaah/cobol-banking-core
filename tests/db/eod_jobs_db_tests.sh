#!/usr/bin/env bash
# EOD batch jobs (PR-5c): list/hold-expiry/dormant/recon/statement.
set -u
export DORMANT_AFTER_DAYS=30
export DORMANT_GRACE_DAYS=1
JD="2099-01-16"
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

assert_match "job list ok" "$(run_cobol "EODJOB_LIST|50|0||||${A}")" "SUCCESS\|"
assert_match "hold expiry ok" "$(run_cobol "EODJOB_HOLD_EXPIRY|${JD}|||||${A}")" "SUCCESS\|"
assert_match "hold expiry persisted" "$(db_query "SELECT COUNT(*) FROM eod_job_run WHERE business_date='${JD}' AND job_code='HOLD_EXPIRY';")" "^1$"
assert_match "dormant mark ok" "$(run_cobol "EODJOB_DORMANT_MARK|${JD}|||||${A}")" "SUCCESS\|"
assert_match "recon ok" "$(run_cobol "EODJOB_RECON|${JD}|||||${A}")" "SUCCESS\|"
assert_match "statement ok" "$(run_cobol "EODJOB_STATEMENT|${JD}|${JD}|USD|||${A}")" "SUCCESS\|"
assert_match "jobs recorded" "$(db_query "SELECT COUNT(*) FROM eod_job_run WHERE business_date='${JD}';")" "^4$"
assert_match "non-admin list refused" "$(run_cobol "EODJOB_LIST|50|0||||sender@test.com")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM eod_job_run WHERE business_date='${JD}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
