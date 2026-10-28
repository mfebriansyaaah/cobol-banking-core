#!/usr/bin/env bash
# Securitization (Wave12) end-to-end DB tests via the COBOL binary.
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
db_reset_securitization

# Create a cost center.
create_out="$(run_cobol "SEC_CREATE|SEC-W12-1|SecA|SPV|||admin@test.com")"
assert_match "SEC_CREATE ok" "$create_out" "SUCCESS\|SEC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM securitization WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SEC_CREATE|SEC-W12-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SEC_GET ok" "$(run_cobol "SEC_GET|${id}|||||admin@test.com")" "SUCCESS\|SEC_GET\|${id}\|SEC-W12-1"
assert_match "SEC_LIST ok" "$(run_cobol "SEC_LIST|||50|0||admin@test.com")" "SEC-W12-1"

# Allocate.
assert_match "SEC_CALC ok" "$(run_cobol "SEC_CALC|${id}|||||admin@test.com")" "SUCCESS\|SEC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM securitization WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SEC_DELETE ok" "$(run_cobol "SEC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SEC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM securitization WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "SEC_SUMMARY ok" "$(run_cobol "SEC_SUMMARY||||||admin@test.com")" "SUCCESS\|SEC_SUMMARY"
assert_match "SEC_AUDIT ok" "$(run_cobol "SEC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SEC_AUDIT"
assert_match "SEC_VALIDATE ok" "$(run_cobol "SEC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SEC_VALID"
assert_match "non-admin refused" "$(run_cobol "SEC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0