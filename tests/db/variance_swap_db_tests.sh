#!/usr/bin/env bash
# Variance swap (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_variance_swap

# Create a cost center.
create_out="$(run_cobol "VRS_CREATE|VRS-W9-1|CounterpartyA|VARIANCE|||admin@test.com")"
assert_match "VRS_CREATE ok" "$create_out" "SUCCESS\|VRS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM variance_swap WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "VRS_CREATE|VRS-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "VRS_GET ok" "$(run_cobol "VRS_GET|${id}|||||admin@test.com")" "SUCCESS\|VRS_GET\|${id}\|VRS-W9-1"
assert_match "VRS_LIST ok" "$(run_cobol "VRS_LIST|||50|0||admin@test.com")" "VRS-W9-1"

# Allocate.
assert_match "VRS_CALC ok" "$(run_cobol "VRS_CALC|${id}|||||admin@test.com")" "SUCCESS\|VRS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM variance_swap WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "VRS_DELETE ok" "$(run_cobol "VRS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|VRS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM variance_swap WHERE id=${id};")" "^MATURED$"

# Summary and audit.
assert_match "VRS_SUMMARY ok" "$(run_cobol "VRS_SUMMARY||||||admin@test.com")" "SUCCESS\|VRS_SUMMARY"
assert_match "VRS_AUDIT ok" "$(run_cobol "VRS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|VRS_AUDIT"
assert_match "VRS_VALIDATE ok" "$(run_cobol "VRS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|VRS_VALID"
assert_match "non-admin refused" "$(run_cobol "VRS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM variance_swap WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM variance_swap_audit WHERE variance_swap_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "VRS_UPDATE|${id}|CounterpartyA|VARIANCE|||admin@test.com")"
assert_match "VRS_UPDATE ok" "$upd_out" "SUCCESS\\|VRS_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM variance_swap WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM variance_swap_audit WHERE variance_swap_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "VRS_UPDATE|999999|CounterpartyA|VARIANCE|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "VRS_UPDATE|${id}|CounterpartyA|VARIANCE|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0