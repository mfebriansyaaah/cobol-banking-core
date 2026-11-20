#!/usr/bin/env bash
# Compliance calendar lifecycle DB tests via the COBOL binary.
# Domain actions: SCHEDULE (OPEN->ACTIVE with due date), COMPLETE
# (ACTIVE +1, capped at max), ESCALATE (overdue + reason, audited),
# CLOSE (no pending events + reason -> CLOSED).
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
db_reset_compliance_calendar

# Create with max events.
create_out="$(run_cobol "CCL_CREATE|CCL-W3-1|EventA|REG|2||admin@test.com")"
assert_match "CCL_CREATE ok" "$create_out" "SUCCESS\|CCL_CREATE\|[0-9]+"
assert_match "create non-admin refused" "$(run_cobol "CCL_CREATE|CCL-P10-1|EventA|REG|||sender@test.com")" "ERROR\|FORBIDDEN"
assert_match "create missing ref" "$(run_cobol "CCL_CREATE||||||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "create bad max" "$(run_cobol "CCL_CREATE|CCL-W3-X|EventA|REG|abc||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "create zero max" "$(run_cobol "CCL_CREATE|CCL-W3-Y|EventA|REG|0||admin@test.com")" "ERROR\|INVALID_INPUT"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM compliance_calendar WHERE id=${id};")" "^OPEN$"
assert_match "max persisted" "$(db_query "SELECT max_events FROM compliance_calendar WHERE id=${id};")" "^2.0000$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CCL_CREATE|CCL-W3-1|Other|REG|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CCL_GET ok" "$(run_cobol "CCL_GET|${id}|||||admin@test.com")" "SUCCESS\|CCL_GET\|${id}\|CCL-W3-1"
assert_match "CCL_LIST ok" "$(run_cobol "CCL_LIST|||50|0||admin@test.com")" "CCL-W3-1"

# Schedule: OPEN -> ACTIVE with today-or-later due date.
assert_match "schedule past rejected" "$(run_cobol "CCL_SCHEDULE|${id}|2000-01-01||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "schedule bad format" "$(run_cobol "CCL_SCHEDULE|${id}|tomorrow||||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "schedule missing date" "$(run_cobol "CCL_SCHEDULE|${id}|||||admin@test.com")" "ERROR\|INVALID_INPUT"
future="$(date -d '+30 days' +%F)"
assert_match "CCL_SCHEDULE ok" "$(run_cobol "CCL_SCHEDULE|${id}|${future}||||admin@test.com")" "SUCCESS\|CCL_SCHEDULE\|${id}"
assert_match "scheduled persisted" "$(db_query "SELECT status FROM compliance_calendar WHERE id=${id};")" "^ACTIVE$"
assert_match "schedule twice rejected" "$(run_cobol "CCL_SCHEDULE|${id}|${future}||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "schedule non-admin refused" "$(run_cobol "CCL_SCHEDULE|${id}|${future}||||sender@test.com")" "ERROR\|FORBIDDEN"

# Complete: ACTIVE +1, capped at max.
assert_match "CCL_COMPLETE ok" "$(run_cobol "CCL_COMPLETE|${id}|||||admin@test.com")" "SUCCESS\|CCL_COMPLETE\|${id}"
assert_match "completed persisted" "$(db_query "SELECT completed_events FROM compliance_calendar WHERE id=${id};")" "^1.0000$"
assert_match "complete second ok" "$(run_cobol "CCL_COMPLETE|${id}|||||admin@test.com")" "SUCCESS\|CCL_COMPLETE\|${id}"
assert_match "complete overflow rejected" "$(run_cobol "CCL_COMPLETE|${id}|||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "complete non-admin refused" "$(run_cobol "CCL_COMPLETE|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

# Close: no pending events + reason required.
assert_match "close missing reason" "$(run_cobol "CCL_CLOSE|${id}|||||admin@test.com")" "ERROR\|INVALID_INPUT"
close_out="$(run_cobol "CCL_CLOSE|${id}|cycle done||||admin@test.com")"
assert_match "CCL_CLOSE ok" "$close_out" "SUCCESS\|CCL_CLOSE\|${id}"
assert_match "closed persisted" "$(db_query "SELECT status FROM compliance_calendar WHERE id=${id};")" "^CLOSED$"
assert_match "close audited" "$(db_query "SELECT COUNT(*) FROM compliance_calendar_audit WHERE compliance_calendar_id=${id} AND action='CLOSE';")" "^1$"
assert_match "complete on closed rejected" "$(run_cobol "CCL_COMPLETE|${id}|||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "close on closed rejected" "$(run_cobol "CCL_CLOSE|${id}|again||||admin@test.com")" "ERROR\|INVALID_STATUS"

# Close blocked by pending events.
pend_out="$(run_cobol "CCL_CREATE|CCL-W3-2|EventB|REG|5||admin@test.com")"
pend_id="$(printf '%s' "$pend_out" | awk -F'|' '{print $3}')"
run_cobol "CCL_SCHEDULE|${pend_id}|${future}||||admin@test.com" > /dev/null
assert_match "close with pending rejected" "$(run_cobol "CCL_CLOSE|${pend_id}|too early||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "pending close keeps status" "$(db_query "SELECT status FROM compliance_calendar WHERE id=${pend_id};")" "^ACTIVE$"

# Escalate: overdue + reason, audited.
assert_match "escalate not-overdue rejected" "$(run_cobol "CCL_ESCALATE|${pend_id}|late||||admin@test.com")" "ERROR\|INVALID_STATUS"
db_exec "UPDATE compliance_calendar SET activated_at='2000-01-01 00:00:00' WHERE id=${pend_id};"
assert_match "escalate missing reason" "$(run_cobol "CCL_ESCALATE|${pend_id}|||||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "CCL_ESCALATE ok" "$(run_cobol "CCL_ESCALATE|${pend_id}|needs review||||admin@test.com")" "SUCCESS\|CCL_ESCALATE\|${pend_id}"
assert_match "escalate audited" "$(db_query "SELECT COUNT(*) FROM compliance_calendar_audit WHERE compliance_calendar_id=${pend_id} AND action='ESCALATE';")" "^1$"
assert_match "escalate non-admin refused" "$(run_cobol "CCL_ESCALATE|${pend_id}|late||||sender@test.com")" "ERROR\|FORBIDDEN"

# Summary and audit.
assert_match "CCL_SUMMARY ok" "$(run_cobol "CCL_SUMMARY||||||admin@test.com")" "SUCCESS\|CCL_SUMMARY"
assert_match "CCL_AUDIT ok" "$(run_cobol "CCL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CCL_AUDIT"
assert_match "CCL_VALIDATE ok" "$(run_cobol "CCL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CCL_VALID"
assert_match "non-admin refused" "$(run_cobol "CCL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM compliance_calendar WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM compliance_calendar_audit WHERE compliance_calendar_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "CCL_UPDATE|${id}|EventA|REG|||admin@test.com")"
assert_match "CCL_UPDATE ok" "$upd_out" "SUCCESS\\|CCL_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM compliance_calendar WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM compliance_calendar_audit WHERE compliance_calendar_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "CCL_UPDATE|999999|EventA|REG|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "CCL_UPDATE|${id}|EventA|REG|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
