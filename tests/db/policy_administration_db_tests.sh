#!/usr/bin/env bash
# Policy admin (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_policy_administration

# Create a cost center.
create_out="$(run_cobol "PAD_CREATE|PAD-W7-1|AdminA|UPDATE|||admin@test.com")"
assert_match "PAD_CREATE ok" "$create_out" "SUCCESS\|PAD_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM policy_administration WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PAD_CREATE|PAD-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PAD_GET ok" "$(run_cobol "PAD_GET|${id}|||||admin@test.com")" "SUCCESS\|PAD_GET\|${id}\|PAD-W7-1"
assert_match "PAD_LIST ok" "$(run_cobol "PAD_LIST|||50|0||admin@test.com")" "PAD-W7-1"

# Allocate.
assert_match "PAD_CALC ok" "$(run_cobol "PAD_CALC|${id}|||||admin@test.com")" "SUCCESS\|PAD_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM policy_administration WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PAD_DELETE ok" "$(run_cobol "PAD_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PAD_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM policy_administration WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PAD_SUMMARY ok" "$(run_cobol "PAD_SUMMARY||||||admin@test.com")" "SUCCESS\|PAD_SUMMARY"
assert_match "PAD_AUDIT ok" "$(run_cobol "PAD_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PAD_AUDIT"
assert_match "PAD_VALIDATE ok" "$(run_cobol "PAD_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PAD_VALID"
assert_match "non-admin refused" "$(run_cobol "PAD_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM policy_administration WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM policy_administration_audit WHERE policy_administration_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "PAD_UPDATE|${id}|AdminA|UPDATE|||admin@test.com")"
assert_match "PAD_UPDATE ok" "$upd_out" "SUCCESS\\|PAD_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM policy_administration WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM policy_administration_audit WHERE policy_administration_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "PAD_UPDATE|999999|AdminA|UPDATE|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "PAD_UPDATE|${id}|AdminA|UPDATE|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0