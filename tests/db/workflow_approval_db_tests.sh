#!/usr/bin/env bash
# workflow_approval (Wave1) end-to-end DB tests via the COBOL binary.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
if ! db_available; then echo "SKIP: DB unavailable"; exit 0; fi

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

db_seed
db_reset_workflow_approval

# Create a cost center.
create_out="$(run_cobol "WFA_CREATE|WFA-W1-1|Change Request|CHANGE|||admin@test.com")"
assert_match "WFA_CREATE ok" "$create_out" "SUCCESS\|WFA_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM workflow_approval WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "WFA_CREATE|WFA-W1-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "WFA_GET ok" "$(run_cobol "WFA_GET|${id}|||||admin@test.com")" "SUCCESS\|WFA_GET\|${id}\|WFA-W1-1"
assert_match "WFA_LIST ok" "$(run_cobol "WFA_LIST|||50|0||admin@test.com")" "WFA-W1-1"

# Allocate.
assert_match "WFA_CALC ok" "$(run_cobol "WFA_CALC|${id}|||||admin@test.com")" "SUCCESS\|WFA_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT decision_count FROM workflow_approval WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "WFA_DELETE ok" "$(run_cobol "WFA_DELETE|${id}|DECIDED||||admin@test.com")" "SUCCESS\|WFA_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM workflow_approval WHERE id=${id};")" "^DECIDED$"

# Summary and audit.
assert_match "WFA_SUMMARY ok" "$(run_cobol "WFA_SUMMARY||||||admin@test.com")" "SUCCESS\|WFA_SUMMARY"
assert_match "WFA_AUDIT ok" "$(run_cobol "WFA_AUDIT|50|0||||admin@test.com")" "SUCCESS\|WFA_AUDIT"
assert_match "WFA_VALIDATE ok" "$(run_cobol "WFA_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|WFA_VALID"
assert_match "non-admin refused" "$(run_cobol "WFA_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0