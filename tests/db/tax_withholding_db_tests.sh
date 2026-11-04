#!/usr/bin/env bash
# Tax withholding (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_tax_withholding

# Create a cost center.
create_out="$(run_cobol "TXW_CREATE|TXW-W10-1|EmployeeA|PPH21|||admin@test.com")"
assert_match "TXW_CREATE ok" "$create_out" "SUCCESS\|TXW_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM tax_withholding WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "TXW_CREATE|TXW-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "TXW_GET ok" "$(run_cobol "TXW_GET|${id}|||||admin@test.com")" "SUCCESS\|TXW_GET\|${id}\|TXW-W10-1"
assert_match "TXW_LIST ok" "$(run_cobol "TXW_LIST|||50|0||admin@test.com")" "TXW-W10-1"

# Allocate.
assert_match "TXW_CALC ok" "$(run_cobol "TXW_CALC|${id}|||||admin@test.com")" "SUCCESS\|TXW_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM tax_withholding WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "TXW_DELETE ok" "$(run_cobol "TXW_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|TXW_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM tax_withholding WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "TXW_SUMMARY ok" "$(run_cobol "TXW_SUMMARY||||||admin@test.com")" "SUCCESS\|TXW_SUMMARY"
assert_match "TXW_AUDIT ok" "$(run_cobol "TXW_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TXW_AUDIT"
assert_match "TXW_VALIDATE ok" "$(run_cobol "TXW_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TXW_VALID"
assert_match "non-admin refused" "$(run_cobol "TXW_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM tax_withholding WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM tax_withholding_audit WHERE tax_withholding_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "TXW_UPDATE|${id}|EmployeeA|PPH21|||admin@test.com")"
assert_match "TXW_UPDATE ok" "$upd_out" "SUCCESS\\|TXW_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM tax_withholding WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM tax_withholding_audit WHERE tax_withholding_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "TXW_UPDATE|999999|EmployeeA|PPH21|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "TXW_UPDATE|${id}|EmployeeA|PPH21|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0