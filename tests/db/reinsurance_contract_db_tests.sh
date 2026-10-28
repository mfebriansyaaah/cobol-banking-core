#!/usr/bin/env bash
# Reinsurance contract (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_reinsurance_contract

# Create a cost center.
create_out="$(run_cobol "RIC_CREATE|RIC-W7-1|ReinsA|TREATY|||admin@test.com")"
assert_match "RIC_CREATE ok" "$create_out" "SUCCESS\|RIC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM reinsurance_contract WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RIC_CREATE|RIC-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RIC_GET ok" "$(run_cobol "RIC_GET|${id}|||||admin@test.com")" "SUCCESS\|RIC_GET\|${id}\|RIC-W7-1"
assert_match "RIC_LIST ok" "$(run_cobol "RIC_LIST|||50|0||admin@test.com")" "RIC-W7-1"

# Allocate.
assert_match "RIC_CALC ok" "$(run_cobol "RIC_CALC|${id}|||||admin@test.com")" "SUCCESS\|RIC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM reinsurance_contract WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "RIC_DELETE ok" "$(run_cobol "RIC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|RIC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM reinsurance_contract WHERE id=${id};")" "^TERMINATED$"

# Summary and audit.
assert_match "RIC_SUMMARY ok" "$(run_cobol "RIC_SUMMARY||||||admin@test.com")" "SUCCESS\|RIC_SUMMARY"
assert_match "RIC_AUDIT ok" "$(run_cobol "RIC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RIC_AUDIT"
assert_match "RIC_VALIDATE ok" "$(run_cobol "RIC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RIC_VALID"
assert_match "non-admin refused" "$(run_cobol "RIC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0