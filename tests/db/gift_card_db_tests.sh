#!/usr/bin/env bash
# Gift card (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_gift_card

# Create a cost center.
create_out="$(run_cobol "GFC_CREATE|GFC-W8-1|CardholderA|DIGITAL|||admin@test.com")"
assert_match "GFC_CREATE ok" "$create_out" "SUCCESS\|GFC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM gift_card WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "GFC_CREATE|GFC-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "GFC_GET ok" "$(run_cobol "GFC_GET|${id}|||||admin@test.com")" "SUCCESS\|GFC_GET\|${id}\|GFC-W8-1"
assert_match "GFC_LIST ok" "$(run_cobol "GFC_LIST|||50|0||admin@test.com")" "GFC-W8-1"

# Allocate.
assert_match "GFC_CALC ok" "$(run_cobol "GFC_CALC|${id}|||||admin@test.com")" "SUCCESS\|GFC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM gift_card WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "GFC_DELETE ok" "$(run_cobol "GFC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|GFC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM gift_card WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "GFC_SUMMARY ok" "$(run_cobol "GFC_SUMMARY||||||admin@test.com")" "SUCCESS\|GFC_SUMMARY"
assert_match "GFC_AUDIT ok" "$(run_cobol "GFC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|GFC_AUDIT"
assert_match "GFC_VALIDATE ok" "$(run_cobol "GFC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|GFC_VALID"
assert_match "non-admin refused" "$(run_cobol "GFC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0