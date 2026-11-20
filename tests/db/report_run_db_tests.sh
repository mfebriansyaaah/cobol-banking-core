#!/usr/bin/env bash
# Report runs (PR-5c): start/generate/row/status/complete/export + guard.
set -u
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
T="RPT-RUN-D1"
db_exec "DELETE FROM report_run WHERE template_id IN (SELECT id FROM report_template WHERE template_code='${T}');"
db_exec "DELETE FROM report_template_column WHERE template_id IN (SELECT id FROM report_template WHERE template_code='${T}');"
db_exec "DELETE FROM report_template WHERE template_code='${T}';"

assert_match "template create ok" "$(run_cobol "RPT_TEMPLATE_CREATE|${T}|Run Report|TRIAL_BALANCE|CSV|Run Title|${A}")" "SUCCESS\|"
assert_match "column create ok" "$(run_cobol "RPT_COLUMN_CREATE|${T}|1|Account|account|20,LEFT,TEXT|${A}")" "SUCCESS\|"
assert_match "run start ok" "$(run_cobol "RPT_RUN_START|${T}|from=2026-01-01||||${A}")" "SUCCESS\|"
runid="$(db_query "SELECT id FROM report_run WHERE template_id=(SELECT id FROM report_template WHERE template_code='${T}') ORDER BY id DESC LIMIT 1;")"
assert_match "run persisted" "$runid" "^[0-9]+$"
assert_match "generate ok" "$(run_cobol "RPT_RUN_GENERATE|${runid}|2026-01-01|2026-12-31|USD||${A}")" "SUCCESS\|"
assert_match "row ok" "$(run_cobol "RPT_RUN_ROW|${runid}|99|10.00|10.00|row99|${A}")" "SUCCESS\|"
assert_match "status ok" "$(run_cobol "RPT_RUN_STATUS|${runid}|||||${A}")" "SUCCESS\|"
counts="$(db_query "SELECT CONCAT(COUNT(*), ',', COALESCE(SUM(debit),0), ',', COALESCE(SUM(credit),0)) FROM report_run_row WHERE run_id=${runid};")"
assert_match "complete ok" "$(run_cobol "RPT_RUN_COMPLETE|${runid}|${counts}|abc123|||${A}")" "SUCCESS\|"
assert_match "export ok" "$(run_cobol "RPT_RUN_EXPORT|${runid}|CSV||||${A}")" "SUCCESS\|"
assert_match "list ok" "$(run_cobol "RPT_RUN_LIST|50|0||||${A}")" "SUCCESS\|"
assert_match "non-admin start refused" "$(run_cobol "RPT_RUN_START|${T}|from=2026-01-01||||sender@test.com")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM report_run_row WHERE run_id=${runid};"
db_exec "DELETE FROM report_run WHERE id=${runid};"
db_exec "DELETE FROM report_template_column WHERE template_id IN (SELECT id FROM report_template WHERE template_code='${T}');"
db_exec "DELETE FROM report_template WHERE template_code='${T}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
