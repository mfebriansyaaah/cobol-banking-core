#!/usr/bin/env bash
# SLA tracker lifecycle DB tests via the COBOL binary.
# Domain actions: BREACH (actual > target check), ESCALATE (breached +
# reason, audited), CLOSE (reason required -> CLOSED).
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
db_reset_sla_tracker

# Create with target.
create_out="$(run_cobol "SLT_CREATE|SLT-W4-1|Resp|P1|2||admin@test.com")"
assert_match "SLT_CREATE ok" "$create_out" "SUCCESS\|SLT_CREATE\|[0-9]+"
assert_match "create non-admin refused" "$(run_cobol "SLT_CREATE|SLT-P10-1|Resp|P1|||sender@test.com")" "ERROR\|FORBIDDEN"
assert_match "create missing ref" "$(run_cobol "SLT_CREATE||||||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "create bad target" "$(run_cobol "SLT_CREATE|SLT-W4-X|Resp|P1|x||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "create zero target" "$(run_cobol "SLT_CREATE|SLT-W4-Y|Resp|P1|0||admin@test.com")" "ERROR\|INVALID_INPUT"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM sla_tracker WHERE id=${id};")" "^OPEN$"
assert_match "target persisted" "$(db_query "SELECT target_response FROM sla_tracker WHERE id=${id};")" "^2.0000$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SLT_CREATE|SLT-W4-1|Other|P1|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SLT_GET ok" "$(run_cobol "SLT_GET|${id}|||||admin@test.com")" "SUCCESS\|SLT_GET\|${id}\|SLT-W4-1"
assert_match "SLT_LIST ok" "$(run_cobol "SLT_LIST|||50|0||admin@test.com")" "SLT-W4-1"

# Breach: actual <= target -> 0.
assert_match "breach within target" "$(run_cobol "SLT_BREACH|${id}|||||admin@test.com")" "SUCCESS\|SLT_BREACH\|0"
assert_match "breach missing id" "$(run_cobol "SLT_BREACH|999999|||||admin@test.com")" "ERROR\|NOT_FOUND"
assert_match "breach non-admin refused" "$(run_cobol "SLT_BREACH|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

# Record actuals via UPDATE, then breach flips to 1.
assert_match "update actual ok" "$(run_cobol "SLT_UPDATE|${id}||||3|admin@test.com")" "SUCCESS\|SLT_UPDATE"
assert_match "actual persisted" "$(db_query "SELECT actual_response FROM sla_tracker WHERE id=${id};")" "^3.0000$"
assert_match "breach detected" "$(run_cobol "SLT_BREACH|${id}|||||admin@test.com")" "SUCCESS\|SLT_BREACH\|1"
assert_match "update bad actual" "$(run_cobol "SLT_UPDATE|${id}||||x|admin@test.com")" "ERROR\|INVALID_INPUT"

# Escalate: breached + reason, audited.
assert_match "escalate missing reason" "$(run_cobol "SLT_ESCALATE|${id}|||||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "SLT_ESCALATE ok" "$(run_cobol "SLT_ESCALATE|${id}|too slow||||admin@test.com")" "SUCCESS\|SLT_ESCALATE\|${id}"
assert_match "escalate audited" "$(db_query "SELECT COUNT(*) FROM sla_tracker_audit WHERE sla_tracker_id=${id} AND action='ESCALATE';")" "^1$"
assert_match "escalate non-admin refused" "$(run_cobol "SLT_ESCALATE|${id}|too slow||||sender@test.com")" "ERROR\|FORBIDDEN"

# Escalate rejected when not breached.
fresh_out="$(run_cobol "SLT_CREATE|SLT-W4-2|Resp2|P1|5||admin@test.com")"
fresh_id="$(printf '%s' "$fresh_out" | awk -F'|' '{print $3}')"
assert_match "escalate within-target rejected" "$(run_cobol "SLT_ESCALATE|${fresh_id}|slow||||admin@test.com")" "ERROR\|INVALID_STATUS"

# Close: reason required -> CLOSED.
assert_match "close missing reason" "$(run_cobol "SLT_CLOSE|${id}|||||admin@test.com")" "ERROR\|INVALID_INPUT"
close_out="$(run_cobol "SLT_CLOSE|${id}|done||||admin@test.com")"
assert_match "SLT_CLOSE ok" "$close_out" "SUCCESS\|SLT_CLOSE\|${id}"
assert_match "closed persisted" "$(db_query "SELECT status FROM sla_tracker WHERE id=${id};")" "^CLOSED$"
assert_match "close audited" "$(db_query "SELECT COUNT(*) FROM sla_tracker_audit WHERE sla_tracker_id=${id} AND action='CLOSE';")" "^1$"
assert_match "breach on closed rejected" "$(run_cobol "SLT_BREACH|${id}|||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "close on closed rejected" "$(run_cobol "SLT_CLOSE|${id}|again||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "close non-admin refused" "$(run_cobol "SLT_CLOSE|${id}|done||||sender@test.com")" "ERROR\|FORBIDDEN"

# Summary and audit.
assert_match "SLT_SUMMARY ok" "$(run_cobol "SLT_SUMMARY||||||admin@test.com")" "SUCCESS\|SLT_SUMMARY"
assert_match "SLT_AUDIT ok" "$(run_cobol "SLT_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SLT_AUDIT"
assert_match "SLT_VALIDATE ok" "$(run_cobol "SLT_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SLT_VALID"
assert_match "non-admin refused" "$(run_cobol "SLT_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM sla_tracker WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM sla_tracker_audit WHERE sla_tracker_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "SLT_UPDATE|${id}|Resp|P1|||admin@test.com")"
assert_match "SLT_UPDATE ok" "$upd_out" "SUCCESS\\|SLT_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM sla_tracker WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM sla_tracker_audit WHERE sla_tracker_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "SLT_UPDATE|999999|Resp|P1|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "SLT_UPDATE|${id}|Resp|P1|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
