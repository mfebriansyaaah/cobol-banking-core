#!/usr/bin/env bash
# Credit card (Wave5) end-to-end DB tests via the COBOL binary.
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
db_reset_credit_card

# Create a cost center.
create_out="$(run_cobol "CRC_CREATE|CRC-W5-1|HolderA|VISA|||admin@test.com")"
assert_match "CRC_CREATE ok" "$create_out" "SUCCESS\|CRC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM credit_card WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CRC_CREATE|CRC-W5-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CRC_GET ok" "$(run_cobol "CRC_GET|${id}|||||admin@test.com")" "SUCCESS\|CRC_GET\|${id}\|CRC-W5-1"
assert_match "CRC_LIST ok" "$(run_cobol "CRC_LIST|||50|0||admin@test.com")" "CRC-W5-1"

# Allocate.
assert_match "CRC_CALC ok" "$(run_cobol "CRC_CALC|${id}|||||admin@test.com")" "SUCCESS\|CRC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT outstanding_balance FROM credit_card WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CRC_DELETE ok" "$(run_cobol "CRC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CRC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM credit_card WHERE id=${id};")" "^CANCELLED$"

# Summary and audit.
assert_match "CRC_SUMMARY ok" "$(run_cobol "CRC_SUMMARY||||||admin@test.com")" "SUCCESS\|CRC_SUMMARY"
assert_match "CRC_AUDIT ok" "$(run_cobol "CRC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CRC_AUDIT"
assert_match "CRC_VALIDATE ok" "$(run_cobol "CRC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CRC_VALID"
assert_match "non-admin refused" "$(run_cobol "CRC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0