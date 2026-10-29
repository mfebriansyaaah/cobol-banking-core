#!/usr/bin/env bash
# Internet banking 2 (Wave20) end-to-end DB tests via the COBOL binary.
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
db_reset_internet_banking2

# Create a cost center.
create_out="$(run_cobol "IBNK_CREATE|IBNK-W20-1|BankA|WEB|||admin@test.com")"
assert_match "IBNK_CREATE ok" "$create_out" "SUCCESS\|IBNK_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM internet_banking2 WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "IBNK_CREATE|IBNK-W20-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "IBNK_GET ok" "$(run_cobol "IBNK_GET|${id}|||||admin@test.com")" "SUCCESS\|IBNK_GET\|${id}\|IBNK-W20-1"
assert_match "IBNK_LIST ok" "$(run_cobol "IBNK_LIST|||50|0||admin@test.com")" "IBNK-W20-1"

# Allocate.
assert_match "IBNK_CALC ok" "$(run_cobol "IBNK_CALC|${id}|||||admin@test.com")" "SUCCESS\|IBNK_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM internet_banking2 WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "IBNK_DELETE ok" "$(run_cobol "IBNK_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|IBNK_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM internet_banking2 WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "IBNK_SUMMARY ok" "$(run_cobol "IBNK_SUMMARY||||||admin@test.com")" "SUCCESS\|IBNK_SUMMARY"
assert_match "IBNK_AUDIT ok" "$(run_cobol "IBNK_AUDIT|50|0||||admin@test.com")" "SUCCESS\|IBNK_AUDIT"
assert_match "IBNK_VALIDATE ok" "$(run_cobol "IBNK_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|IBNK_VALID"
assert_match "non-admin refused" "$(run_cobol "IBNK_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0