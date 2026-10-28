#!/usr/bin/env bash
# Escrow account (Wave4) end-to-end DB tests via the COBOL binary.
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
db_reset_escrow_account

# Create a cost center.
create_out="$(run_cobol "ESC_CREATE|ESC-W4-1|EscrowA|M&A|||admin@test.com")"
assert_match "ESC_CREATE ok" "$create_out" "SUCCESS\|ESC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM escrow_account WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ESC_CREATE|ESC-W4-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ESC_GET ok" "$(run_cobol "ESC_GET|${id}|||||admin@test.com")" "SUCCESS\|ESC_GET\|${id}\|ESC-W4-1"
assert_match "ESC_LIST ok" "$(run_cobol "ESC_LIST|||50|0||admin@test.com")" "ESC-W4-1"

# Allocate.
assert_match "ESC_CALC ok" "$(run_cobol "ESC_CALC|${id}|||||admin@test.com")" "SUCCESS\|ESC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT released_amount FROM escrow_account WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ESC_DELETE ok" "$(run_cobol "ESC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ESC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM escrow_account WHERE id=${id};")" "^RELEASED$"

# Summary and audit.
assert_match "ESC_SUMMARY ok" "$(run_cobol "ESC_SUMMARY||||||admin@test.com")" "SUCCESS\|ESC_SUMMARY"
assert_match "ESC_AUDIT ok" "$(run_cobol "ESC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ESC_AUDIT"
assert_match "ESC_VALIDATE ok" "$(run_cobol "ESC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ESC_VALID"
assert_match "non-admin refused" "$(run_cobol "ESC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0