#!/usr/bin/env bash
# Invoice (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_invoice

# Create a cost center.
create_out="$(run_cobol "INVC_CREATE|INVC-W10-1|CustomerA|SALES|||admin@test.com")"
assert_match "INVC_CREATE ok" "$create_out" "SUCCESS\|INVC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM invoice WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "INVC_CREATE|INVC-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "INVC_GET ok" "$(run_cobol "INVC_GET|${id}|||||admin@test.com")" "SUCCESS\|INVC_GET\|${id}\|INVC-W10-1"
assert_match "INVC_LIST ok" "$(run_cobol "INVC_LIST|||50|0||admin@test.com")" "INVC-W10-1"

# Allocate.
assert_match "INVC_CALC ok" "$(run_cobol "INVC_CALC|${id}|||||admin@test.com")" "SUCCESS\|INVC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM invoice WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "INVC_DELETE ok" "$(run_cobol "INVC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|INVC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM invoice WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "INVC_SUMMARY ok" "$(run_cobol "INVC_SUMMARY||||||admin@test.com")" "SUCCESS\|INVC_SUMMARY"
assert_match "INVC_AUDIT ok" "$(run_cobol "INVC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|INVC_AUDIT"
assert_match "INVC_VALIDATE ok" "$(run_cobol "INVC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|INVC_VALID"
assert_match "non-admin refused" "$(run_cobol "INVC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0