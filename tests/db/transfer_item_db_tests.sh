#!/usr/bin/env bash
# Transfer item (Wave15) end-to-end DB tests via the COBOL binary.
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
db_reset_transfer_item

# Create a cost center.
create_out="$(run_cobol "TRNF_CREATE|TRNF-W15-1|SenderA|INTERNAL|||admin@test.com")"
assert_match "TRNF_CREATE ok" "$create_out" "SUCCESS\|TRNF_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM transfer_item WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "TRNF_CREATE|TRNF-W15-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "TRNF_GET ok" "$(run_cobol "TRNF_GET|${id}|||||admin@test.com")" "SUCCESS\|TRNF_GET\|${id}\|TRNF-W15-1"
assert_match "TRNF_LIST ok" "$(run_cobol "TRNF_LIST|||50|0||admin@test.com")" "TRNF-W15-1"

# Allocate.
assert_match "TRNF_CALC ok" "$(run_cobol "TRNF_CALC|${id}|||||admin@test.com")" "SUCCESS\|TRNF_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM transfer_item WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "TRNF_DELETE ok" "$(run_cobol "TRNF_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|TRNF_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM transfer_item WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "TRNF_SUMMARY ok" "$(run_cobol "TRNF_SUMMARY||||||admin@test.com")" "SUCCESS\|TRNF_SUMMARY"
assert_match "TRNF_AUDIT ok" "$(run_cobol "TRNF_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TRNF_AUDIT"
assert_match "TRNF_VALIDATE ok" "$(run_cobol "TRNF_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TRNF_VALID"
assert_match "non-admin refused" "$(run_cobol "TRNF_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0