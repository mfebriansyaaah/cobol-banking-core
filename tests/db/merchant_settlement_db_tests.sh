#!/usr/bin/env bash
# Merchant settlement (Wave5) end-to-end DB tests via the COBOL binary.
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
db_reset_merchant_settlement

# Create a cost center.
create_out="$(run_cobol "MCS_CREATE|MCS-W5-1|MerchantA|DAILY|||admin@test.com")"
assert_match "MCS_CREATE ok" "$create_out" "SUCCESS\|MCS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM merchant_settlement WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MCS_CREATE|MCS-W5-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MCS_GET ok" "$(run_cobol "MCS_GET|${id}|||||admin@test.com")" "SUCCESS\|MCS_GET\|${id}\|MCS-W5-1"
assert_match "MCS_LIST ok" "$(run_cobol "MCS_LIST|||50|0||admin@test.com")" "MCS-W5-1"

# Allocate.
assert_match "MCS_CALC ok" "$(run_cobol "MCS_CALC|${id}|||||admin@test.com")" "SUCCESS\|MCS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT paid_amount FROM merchant_settlement WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MCS_DELETE ok" "$(run_cobol "MCS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MCS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM merchant_settlement WHERE id=${id};")" "^SETTLED$"

# Summary and audit.
assert_match "MCS_SUMMARY ok" "$(run_cobol "MCS_SUMMARY||||||admin@test.com")" "SUCCESS\|MCS_SUMMARY"
assert_match "MCS_AUDIT ok" "$(run_cobol "MCS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MCS_AUDIT"
assert_match "MCS_VALIDATE ok" "$(run_cobol "MCS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MCS_VALID"
assert_match "non-admin refused" "$(run_cobol "MCS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0