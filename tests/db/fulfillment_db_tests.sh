#!/usr/bin/env bash
# Fulfillment (Wave19) end-to-end DB tests via the COBOL binary.
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
db_reset_fulfillment

# Create a cost center.
create_out="$(run_cobol "FLF_CREATE|FLF-W19-1|FulfillmentA|ORDER|||admin@test.com")"
assert_match "FLF_CREATE ok" "$create_out" "SUCCESS\|FLF_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM fulfillment WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "FLF_CREATE|FLF-W19-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "FLF_GET ok" "$(run_cobol "FLF_GET|${id}|||||admin@test.com")" "SUCCESS\|FLF_GET\|${id}\|FLF-W19-1"
assert_match "FLF_LIST ok" "$(run_cobol "FLF_LIST|||50|0||admin@test.com")" "FLF-W19-1"

# Allocate.
assert_match "FLF_CALC ok" "$(run_cobol "FLF_CALC|${id}|||||admin@test.com")" "SUCCESS\|FLF_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM fulfillment WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "FLF_DELETE ok" "$(run_cobol "FLF_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|FLF_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM fulfillment WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "FLF_SUMMARY ok" "$(run_cobol "FLF_SUMMARY||||||admin@test.com")" "SUCCESS\|FLF_SUMMARY"
assert_match "FLF_AUDIT ok" "$(run_cobol "FLF_AUDIT|50|0||||admin@test.com")" "SUCCESS\|FLF_AUDIT"
assert_match "FLF_VALIDATE ok" "$(run_cobol "FLF_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|FLF_VALID"
assert_match "non-admin refused" "$(run_cobol "FLF_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0