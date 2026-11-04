#!/usr/bin/env bash
# Dispute management (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_dispute_management

# Create a cost center.
create_out="$(run_cobol "DSM_CREATE|DSM-W6-1|DisputeA|FRAUD|||admin@test.com")"
assert_match "DSM_CREATE ok" "$create_out" "SUCCESS\|DSM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM dispute_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DSM_CREATE|DSM-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DSM_GET ok" "$(run_cobol "DSM_GET|${id}|||||admin@test.com")" "SUCCESS\|DSM_GET\|${id}\|DSM-W6-1"
assert_match "DSM_LIST ok" "$(run_cobol "DSM_LIST|||50|0||admin@test.com")" "DSM-W6-1"

# Allocate.
assert_match "DSM_CALC ok" "$(run_cobol "DSM_CALC|${id}|||||admin@test.com")" "SUCCESS\|DSM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM dispute_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DSM_DELETE ok" "$(run_cobol "DSM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|DSM_DELETE"
assert_match "resolved persisted" "$(db_query "SELECT status FROM dispute_management WHERE id=${id};")" "^RESOLVED$"

# Summary and audit.
assert_match "DSM_SUMMARY ok" "$(run_cobol "DSM_SUMMARY||||||admin@test.com")" "SUCCESS\|DSM_SUMMARY"
assert_match "DSM_AUDIT ok" "$(run_cobol "DSM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DSM_AUDIT"
assert_match "DSM_VALIDATE ok" "$(run_cobol "DSM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DSM_VALID"
assert_match "non-admin refused" "$(run_cobol "DSM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM dispute_management WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM dispute_management_audit WHERE dispute_management_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "DSM_UPDATE|${id}|DisputeA|FRAUD|||admin@test.com")"
assert_match "DSM_UPDATE ok" "$upd_out" "SUCCESS\\|DSM_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM dispute_management WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM dispute_management_audit WHERE dispute_management_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "DSM_UPDATE|999999|DisputeA|FRAUD|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "DSM_UPDATE|${id}|DisputeA|FRAUD|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0