#!/usr/bin/env bash
# Customer (Wave1) end-to-end DB tests via the COBOL binary.
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
db_reset_customer

# Create a cost center.
create_out="$(run_cobol "CST_CREATE|CST-W1-1|John Doe|RETAIL|||admin@test.com")"
assert_match "CST_CREATE ok" "$create_out" "SUCCESS\|CST_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM customer WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CST_CREATE|CST-W1-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CST_GET ok" "$(run_cobol "CST_GET|${id}|||||admin@test.com")" "SUCCESS\|CST_GET\|${id}\|CST-W1-1"
assert_match "CST_LIST ok" "$(run_cobol "CST_LIST||RETAIL|50|0||admin@test.com")" "CST-W1-1"

# Allocate.
assert_match "CST_CALC ok" "$(run_cobol "CST_CALC|${id}|||||admin@test.com")" "SUCCESS\|CST_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT used_credit FROM customer WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CST_DELETE ok" "$(run_cobol "CST_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CST_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM customer WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CST_SUMMARY ok" "$(run_cobol "CST_SUMMARY||||||admin@test.com")" "SUCCESS\|CST_SUMMARY"
assert_match "CST_AUDIT ok" "$(run_cobol "CST_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CST_AUDIT"
assert_match "CST_VALIDATE ok" "$(run_cobol "CST_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CST_VALID"
assert_match "non-admin refused" "$(run_cobol "CST_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0