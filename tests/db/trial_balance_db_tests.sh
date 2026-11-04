#!/usr/bin/env bash
# Trial balance (Wave13) end-to-end DB tests via the COBOL binary.
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
db_reset_trial_balance

# Create a cost center.
create_out="$(run_cobol "TB_CREATE|TB-W13-1|EntityA|MONTHLY|||admin@test.com")"
assert_match "TB_CREATE ok" "$create_out" "SUCCESS\|TB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM trial_balance WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "TB_CREATE|TB-W13-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "TB_GET ok" "$(run_cobol "TB_GET|${id}|||||admin@test.com")" "SUCCESS\|TB_GET\|${id}\|TB-W13-1"
assert_match "TB_LIST ok" "$(run_cobol "TB_LIST|||50|0||admin@test.com")" "TB-W13-1"

# Allocate.
assert_match "TB_CALC ok" "$(run_cobol "TB_CALC|${id}|||||admin@test.com")" "SUCCESS\|TB_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM trial_balance WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "TB_DELETE ok" "$(run_cobol "TB_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|TB_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM trial_balance WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "TB_SUMMARY ok" "$(run_cobol "TB_SUMMARY||||||admin@test.com")" "SUCCESS\|TB_SUMMARY"
assert_match "TB_AUDIT ok" "$(run_cobol "TB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TB_AUDIT"
assert_match "TB_VALIDATE ok" "$(run_cobol "TB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TB_VALID"
assert_match "non-admin refused" "$(run_cobol "TB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM trial_balance WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM trial_balance_audit WHERE trial_balance_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "TB_UPDATE|${id}|EntityA|MONTHLY|||admin@test.com")"
assert_match "TB_UPDATE ok" "$upd_out" "SUCCESS\\|TB_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM trial_balance WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM trial_balance_audit WHERE trial_balance_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "TB_UPDATE|999999|EntityA|MONTHLY|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "TB_UPDATE|${id}|EntityA|MONTHLY|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0