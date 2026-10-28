#!/usr/bin/env bash
# Supply chain finance (Wave4) end-to-end DB tests via the COBOL binary.
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
db_reset_supply_chain_finance

# Create a cost center.
create_out="$(run_cobol "SCF_CREATE|SCF-W4-1|SupplierA|PO|||admin@test.com")"
assert_match "SCF_CREATE ok" "$create_out" "SUCCESS\|SCF_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM supply_chain_finance WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SCF_CREATE|SCF-W4-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SCF_GET ok" "$(run_cobol "SCF_GET|${id}|||||admin@test.com")" "SUCCESS\|SCF_GET\|${id}\|SCF-W4-1"
assert_match "SCF_LIST ok" "$(run_cobol "SCF_LIST|||50|0||admin@test.com")" "SCF-W4-1"

# Allocate.
assert_match "SCF_CALC ok" "$(run_cobol "SCF_CALC|${id}|||||admin@test.com")" "SUCCESS\|SCF_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT utilized_amount FROM supply_chain_finance WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SCF_DELETE ok" "$(run_cobol "SCF_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SCF_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM supply_chain_finance WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "SCF_SUMMARY ok" "$(run_cobol "SCF_SUMMARY||||||admin@test.com")" "SUCCESS\|SCF_SUMMARY"
assert_match "SCF_AUDIT ok" "$(run_cobol "SCF_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SCF_AUDIT"
assert_match "SCF_VALIDATE ok" "$(run_cobol "SCF_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SCF_VALID"
assert_match "non-admin refused" "$(run_cobol "SCF_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0