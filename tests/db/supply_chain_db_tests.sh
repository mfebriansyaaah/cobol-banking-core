#!/usr/bin/env bash
# Supply chain (Wave16) end-to-end DB tests via the COBOL binary.
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
db_reset_supply_chain

# Create a cost center.
create_out="$(run_cobol "SCFN_CREATE|SCFN-W16-1|SupplierA|CONFIRMING|||admin@test.com")"
assert_match "SCFN_CREATE ok" "$create_out" "SUCCESS\|SCFN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM supply_chain WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SCFN_CREATE|SCFN-W16-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SCFN_GET ok" "$(run_cobol "SCFN_GET|${id}|||||admin@test.com")" "SUCCESS\|SCFN_GET\|${id}\|SCFN-W16-1"
assert_match "SCFN_LIST ok" "$(run_cobol "SCFN_LIST|||50|0||admin@test.com")" "SCFN-W16-1"

# Allocate.
assert_match "SCFN_CALC ok" "$(run_cobol "SCFN_CALC|${id}|||||admin@test.com")" "SUCCESS\|SCFN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM supply_chain WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SCFN_DELETE ok" "$(run_cobol "SCFN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SCFN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM supply_chain WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "SCFN_SUMMARY ok" "$(run_cobol "SCFN_SUMMARY||||||admin@test.com")" "SUCCESS\|SCFN_SUMMARY"
assert_match "SCFN_AUDIT ok" "$(run_cobol "SCFN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SCFN_AUDIT"
assert_match "SCFN_VALIDATE ok" "$(run_cobol "SCFN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SCFN_VALID"
assert_match "non-admin refused" "$(run_cobol "SCFN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0