#!/usr/bin/env bash
# Milestone payment (Wave16) end-to-end DB tests via the COBOL binary.
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
db_reset_milestone_payment

# Create a cost center.
create_out="$(run_cobol "MSP_CREATE|MSP-W16-1|ProjectA|DELIVERABLE|||admin@test.com")"
assert_match "MSP_CREATE ok" "$create_out" "SUCCESS\|MSP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM milestone_payment WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MSP_CREATE|MSP-W16-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MSP_GET ok" "$(run_cobol "MSP_GET|${id}|||||admin@test.com")" "SUCCESS\|MSP_GET\|${id}\|MSP-W16-1"
assert_match "MSP_LIST ok" "$(run_cobol "MSP_LIST|||50|0||admin@test.com")" "MSP-W16-1"

# Allocate.
assert_match "MSP_CALC ok" "$(run_cobol "MSP_CALC|${id}|||||admin@test.com")" "SUCCESS\|MSP_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM milestone_payment WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MSP_DELETE ok" "$(run_cobol "MSP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MSP_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM milestone_payment WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "MSP_SUMMARY ok" "$(run_cobol "MSP_SUMMARY||||||admin@test.com")" "SUCCESS\|MSP_SUMMARY"
assert_match "MSP_AUDIT ok" "$(run_cobol "MSP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MSP_AUDIT"
assert_match "MSP_VALIDATE ok" "$(run_cobol "MSP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MSP_VALID"
assert_match "non-admin refused" "$(run_cobol "MSP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM milestone_payment WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM milestone_payment_audit WHERE milestone_payment_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "MSP_UPDATE|${id}|ProjectA|DELIVERABLE|||admin@test.com")"
assert_match "MSP_UPDATE ok" "$upd_out" "SUCCESS\\|MSP_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM milestone_payment WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM milestone_payment_audit WHERE milestone_payment_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "MSP_UPDATE|999999|ProjectA|DELIVERABLE|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "MSP_UPDATE|${id}|ProjectA|DELIVERABLE|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0