#!/usr/bin/env bash
# Timeout (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_timeout

# Create a cost center.
create_out="$(run_cobol "TMO_CREATE|TMO-W11-1|OperationA|HARD|||admin@test.com")"
assert_match "TMO_CREATE ok" "$create_out" "SUCCESS\|TMO_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM timeout WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "TMO_CREATE|TMO-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "TMO_GET ok" "$(run_cobol "TMO_GET|${id}|||||admin@test.com")" "SUCCESS\|TMO_GET\|${id}\|TMO-W11-1"
assert_match "TMO_LIST ok" "$(run_cobol "TMO_LIST|||50|0||admin@test.com")" "TMO-W11-1"

# Allocate.
assert_match "TMO_CALC ok" "$(run_cobol "TMO_CALC|${id}|||||admin@test.com")" "SUCCESS\|TMO_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM timeout WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "TMO_DELETE ok" "$(run_cobol "TMO_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|TMO_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM timeout WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "TMO_SUMMARY ok" "$(run_cobol "TMO_SUMMARY||||||admin@test.com")" "SUCCESS\|TMO_SUMMARY"
assert_match "TMO_AUDIT ok" "$(run_cobol "TMO_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TMO_AUDIT"
assert_match "TMO_VALIDATE ok" "$(run_cobol "TMO_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TMO_VALID"
assert_match "non-admin refused" "$(run_cobol "TMO_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM timeout WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM timeout_audit WHERE timeout_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "TMO_UPDATE|${id}|OperationA|HARD|||admin@test.com")"
assert_match "TMO_UPDATE ok" "$upd_out" "SUCCESS\\|TMO_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM timeout WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM timeout_audit WHERE timeout_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "TMO_UPDATE|999999|OperationA|HARD|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "TMO_UPDATE|${id}|OperationA|HARD|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0