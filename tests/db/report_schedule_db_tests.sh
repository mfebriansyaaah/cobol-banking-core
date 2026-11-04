#!/usr/bin/env bash
# Report schedule (Wave3) end-to-end DB tests via the COBOL binary.
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
db_reset_rpt_schedule_config

# Create a cost center.
create_out="$(run_cobol "RPS_CREATE|RPS-W3-1|ScheduleA|DAILY|||admin@test.com")"
assert_match "RPS_CREATE ok" "$create_out" "SUCCESS\|RPS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM rpt_schedule_config WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RPS_CREATE|RPS-W3-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RPS_GET ok" "$(run_cobol "RPS_GET|${id}|||||admin@test.com")" "SUCCESS\|RPS_GET\|${id}\|RPS-W3-1"
assert_match "RPS_LIST ok" "$(run_cobol "RPS_LIST|||50|0||admin@test.com")" "RPS-W3-1"

# Allocate.
assert_match "RPS_CALC ok" "$(run_cobol "RPS_CALC|${id}|||||admin@test.com")" "SUCCESS\|RPS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT run_count FROM rpt_schedule_config WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "RPS_DELETE ok" "$(run_cobol "RPS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|RPS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM rpt_schedule_config WHERE id=${id};")" "^INACTIVE$"

# Summary and audit.
assert_match "RPS_SUMMARY ok" "$(run_cobol "RPS_SUMMARY||||||admin@test.com")" "SUCCESS\|RPS_SUMMARY"
assert_match "RPS_AUDIT ok" "$(run_cobol "RPS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RPS_AUDIT"
assert_match "RPS_VALIDATE ok" "$(run_cobol "RPS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RPS_VALID"
assert_match "non-admin refused" "$(run_cobol "RPS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM rpt_schedule_config WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM rpt_schedule_config_audit WHERE rpt_schedule_config_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "RPS_UPDATE|${id}|ScheduleA|DAILY|||admin@test.com")"
assert_match "RPS_UPDATE ok" "$upd_out" "SUCCESS\\|RPS_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM rpt_schedule_config WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM rpt_schedule_config_audit WHERE rpt_schedule_config_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "RPS_UPDATE|999999|ScheduleA|DAILY|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "RPS_UPDATE|${id}|ScheduleA|DAILY|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0