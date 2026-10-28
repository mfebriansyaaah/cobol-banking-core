#!/usr/bin/env bash
# Smart contract (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_smart_contract

# Create a cost center.
create_out="$(run_cobol "SMC_CREATE|SMC-W6-1|ContractA|ERC20|||admin@test.com")"
assert_match "SMC_CREATE ok" "$create_out" "SUCCESS\|SMC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM smart_contract WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SMC_CREATE|SMC-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SMC_GET ok" "$(run_cobol "SMC_GET|${id}|||||admin@test.com")" "SUCCESS\|SMC_GET\|${id}\|SMC-W6-1"
assert_match "SMC_LIST ok" "$(run_cobol "SMC_LIST|||50|0||admin@test.com")" "SMC-W6-1"

# Allocate.
assert_match "SMC_CALC ok" "$(run_cobol "SMC_CALC|${id}|||||admin@test.com")" "SUCCESS\|SMC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM smart_contract WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SMC_DELETE ok" "$(run_cobol "SMC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SMC_DELETE"
assert_match "terminated persisted" "$(db_query "SELECT status FROM smart_contract WHERE id=${id};")" "^TERMINATED$"

# Summary and audit.
assert_match "SMC_SUMMARY ok" "$(run_cobol "SMC_SUMMARY||||||admin@test.com")" "SUCCESS\|SMC_SUMMARY"
assert_match "SMC_AUDIT ok" "$(run_cobol "SMC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SMC_AUDIT"
assert_match "SMC_VALIDATE ok" "$(run_cobol "SMC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SMC_VALID"
assert_match "non-admin refused" "$(run_cobol "SMC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0