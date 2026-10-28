#!/usr/bin/env bash
# Private equity (Wave12) end-to-end DB tests via the COBOL binary.
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
db_reset_private_equity

# Create a cost center.
create_out="$(run_cobol "PEQ_CREATE|PEQ-W12-1|FundA|BUYOUT|||admin@test.com")"
assert_match "PEQ_CREATE ok" "$create_out" "SUCCESS\|PEQ_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM private_equity WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PEQ_CREATE|PEQ-W12-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PEQ_GET ok" "$(run_cobol "PEQ_GET|${id}|||||admin@test.com")" "SUCCESS\|PEQ_GET\|${id}\|PEQ-W12-1"
assert_match "PEQ_LIST ok" "$(run_cobol "PEQ_LIST|||50|0||admin@test.com")" "PEQ-W12-1"

# Allocate.
assert_match "PEQ_CALC ok" "$(run_cobol "PEQ_CALC|${id}|||||admin@test.com")" "SUCCESS\|PEQ_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM private_equity WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PEQ_DELETE ok" "$(run_cobol "PEQ_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PEQ_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM private_equity WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PEQ_SUMMARY ok" "$(run_cobol "PEQ_SUMMARY||||||admin@test.com")" "SUCCESS\|PEQ_SUMMARY"
assert_match "PEQ_AUDIT ok" "$(run_cobol "PEQ_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PEQ_AUDIT"
assert_match "PEQ_VALIDATE ok" "$(run_cobol "PEQ_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PEQ_VALID"
assert_match "non-admin refused" "$(run_cobol "PEQ_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0