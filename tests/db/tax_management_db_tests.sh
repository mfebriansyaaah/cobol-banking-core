#!/usr/bin/env bash
# Tax management (Wave5) end-to-end DB tests via the COBOL binary.
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
db_reset_tax_management

# Create a cost center.
create_out="$(run_cobol "TXM_CREATE|TXM-W5-1|TaxA|VAT|||admin@test.com")"
assert_match "TXM_CREATE ok" "$create_out" "SUCCESS\|TXM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM tax_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "TXM_CREATE|TXM-W5-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "TXM_GET ok" "$(run_cobol "TXM_GET|${id}|||||admin@test.com")" "SUCCESS\|TXM_GET\|${id}\|TXM-W5-1"
assert_match "TXM_LIST ok" "$(run_cobol "TXM_LIST|||50|0||admin@test.com")" "TXM-W5-1"

# Allocate.
assert_match "TXM_CALC ok" "$(run_cobol "TXM_CALC|${id}|||||admin@test.com")" "SUCCESS\|TXM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT collected_tax FROM tax_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "TXM_DELETE ok" "$(run_cobol "TXM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|TXM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM tax_management WHERE id=${id};")" "^INACTIVE$"

# Summary and audit.
assert_match "TXM_SUMMARY ok" "$(run_cobol "TXM_SUMMARY||||||admin@test.com")" "SUCCESS\|TXM_SUMMARY"
assert_match "TXM_AUDIT ok" "$(run_cobol "TXM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TXM_AUDIT"
assert_match "TXM_VALIDATE ok" "$(run_cobol "TXM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TXM_VALID"
assert_match "non-admin refused" "$(run_cobol "TXM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0