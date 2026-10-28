#!/usr/bin/env bash
# Chargeback (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_chargeback

# Create a cost center.
create_out="$(run_cobol "CHB_CREATE|CHB-W6-1|HolderA|UNAUTH|||admin@test.com")"
assert_match "CHB_CREATE ok" "$create_out" "SUCCESS\|CHB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM chargeback WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CHB_CREATE|CHB-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CHB_GET ok" "$(run_cobol "CHB_GET|${id}|||||admin@test.com")" "SUCCESS\|CHB_GET\|${id}\|CHB-W6-1"
assert_match "CHB_LIST ok" "$(run_cobol "CHB_LIST|||50|0||admin@test.com")" "CHB-W6-1"

# Allocate.
assert_match "CHB_CALC ok" "$(run_cobol "CHB_CALC|${id}|||||admin@test.com")" "SUCCESS\|CHB_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM chargeback WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CHB_DELETE ok" "$(run_cobol "CHB_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CHB_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM chargeback WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CHB_SUMMARY ok" "$(run_cobol "CHB_SUMMARY||||||admin@test.com")" "SUCCESS\|CHB_SUMMARY"
assert_match "CHB_AUDIT ok" "$(run_cobol "CHB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CHB_AUDIT"
assert_match "CHB_VALIDATE ok" "$(run_cobol "CHB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CHB_VALID"
assert_match "non-admin refused" "$(run_cobol "CHB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0