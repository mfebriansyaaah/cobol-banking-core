#!/usr/bin/env bash
# Report schedule lifecycle DB tests via the COBOL binary.
# Domain actions: ENABLE (OPEN/INACTIVE -> ACTIVE), DISABLE (ACTIVE -> INACTIVE
# with reason), RUN_NOW (ACTIVE + below max, increments run_count).
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
db_reset_report_schedule

# Create with max instances.
create_out="$(run_cobol "RPS_CREATE|RPS-W4-1|Nightly|DAILY|5||admin@test.com")"
assert_match "RPS_CREATE ok" "$create_out" "SUCCESS\|RPS_CREATE\|[0-9]+"
assert_match "create non-admin refused" "$(run_cobol "RPS_CREATE|RPS-P10-1|Nightly|DAILY|||sender@test.com")" "ERROR\|FORBIDDEN"
assert_match "create missing ref" "$(run_cobol "RPS_CREATE||||||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "create bad max" "$(run_cobol "RPS_CREATE|RPS-W4-X|Nightly|DAILY|abc||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "create zero max" "$(run_cobol "RPS_CREATE|RPS-W4-Y|Nightly|DAILY|0||admin@test.com")" "ERROR\|INVALID_INPUT"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM rpt_schedule_config WHERE id=${id};")" "^OPEN$"
assert_match "max persisted" "$(db_query "SELECT max_instances FROM rpt_schedule_config WHERE id=${id};")" "^5.0000$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RPS_CREATE|RPS-W4-1|Other|DAILY|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RPS_GET ok" "$(run_cobol "RPS_GET|${id}|||||admin@test.com")" "SUCCESS\|RPS_GET\|${id}\|RPS-W4-1"
assert_match "RPS_LIST ok" "$(run_cobol "RPS_LIST|||50|0||admin@test.com")" "RPS-W4-1"

# Run-now and disable require ACTIVE.
assert_match "run-now on OPEN rejected" "$(run_cobol "RPS_RUN_NOW|${id}|||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "disable on OPEN rejected" "$(run_cobol "RPS_DISABLE|${id}|pause||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "enable on OPEN ok" "$(run_cobol "RPS_ENABLE|${id}|||||admin@test.com")" "SUCCESS\|RPS_ENABLE\|${id}"
assert_match "enabled persisted" "$(db_query "SELECT status FROM rpt_schedule_config WHERE id=${id};")" "^ACTIVE$"
assert_match "enable twice rejected" "$(run_cobol "RPS_ENABLE|${id}|||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "enable non-admin refused" "$(run_cobol "RPS_ENABLE|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

# Run-now: ACTIVE, increments, capped at max.
assert_match "RPS_RUN_NOW ok" "$(run_cobol "RPS_RUN_NOW|${id}|||||admin@test.com")" "SUCCESS\|RPS_RUN_NOW\|${id}"
assert_match "run count persisted" "$(db_query "SELECT run_count FROM rpt_schedule_config WHERE id=${id};")" "^1.0000$"
run_cobol "RPS_RUN_NOW|${id}|||||admin@test.com" > /dev/null
run_cobol "RPS_RUN_NOW|${id}|||||admin@test.com" > /dev/null
run_cobol "RPS_RUN_NOW|${id}|||||admin@test.com" > /dev/null
assert_match "run count at 4" "$(db_query "SELECT run_count FROM rpt_schedule_config WHERE id=${id};")" "^4.0000$"
assert_match "run-now fifth ok" "$(run_cobol "RPS_RUN_NOW|${id}|||||admin@test.com")" "SUCCESS\|RPS_RUN_NOW\|${id}"
assert_match "run-now over cap rejected" "$(run_cobol "RPS_RUN_NOW|${id}|||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "run-now non-admin refused" "$(run_cobol "RPS_RUN_NOW|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

# Disable: ACTIVE -> INACTIVE with reason.
assert_match "disable missing reason" "$(run_cobol "RPS_DISABLE|${id}|||||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "RPS_DISABLE ok" "$(run_cobol "RPS_DISABLE|${id}|holiday||||admin@test.com")" "SUCCESS\|RPS_DISABLE\|${id}"
assert_match "disabled persisted" "$(db_query "SELECT status FROM rpt_schedule_config WHERE id=${id};")" "^INACTIVE$"
assert_match "disable audited" "$(db_query "SELECT COUNT(*) FROM rpt_schedule_config_audit WHERE rpt_schedule_config_id=${id} AND action='DISABLE';")" "^1$"
assert_match "run-now on INACTIVE rejected" "$(run_cobol "RPS_RUN_NOW|${id}|||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "disable twice rejected" "$(run_cobol "RPS_DISABLE|${id}|again||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "disable non-admin refused" "$(run_cobol "RPS_DISABLE|${id}|holiday||||sender@test.com")" "ERROR\|FORBIDDEN"

# Re-enable from INACTIVE.
assert_match "RPS_ENABLE from INACTIVE ok" "$(run_cobol "RPS_ENABLE|${id}|||||admin@test.com")" "SUCCESS\|RPS_ENABLE\|${id}"
assert_match "re-enabled persisted" "$(db_query "SELECT status FROM rpt_schedule_config WHERE id=${id};")" "^ACTIVE$"

# Summary and audit.
assert_match "RPS_SUMMARY ok" "$(run_cobol "RPS_SUMMARY||||||admin@test.com")" "SUCCESS\|RPS_SUMMARY"
assert_match "RPS_AUDIT ok" "$(run_cobol "RPS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RPS_AUDIT"
assert_match "RPS_VALIDATE ok" "$(run_cobol "RPS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RPS_VALID"
assert_match "non-admin refused" "$(run_cobol "RPS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM rpt_schedule_config WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM rpt_schedule_config_audit WHERE rpt_schedule_config_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "RPS_UPDATE|${id}|Nightly|DAILY|||admin@test.com")"
assert_match "RPS_UPDATE ok" "$upd_out" "SUCCESS\\|RPS_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM rpt_schedule_config WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM rpt_schedule_config_audit WHERE rpt_schedule_config_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "RPS_UPDATE|999999|Nightly|DAILY|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "RPS_UPDATE|${id}|Nightly|DAILY|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
