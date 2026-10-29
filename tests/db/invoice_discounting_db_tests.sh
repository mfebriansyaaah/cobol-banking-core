#!/usr/bin/env bash
# Invoice discounting (Wave16) end-to-end DB tests via the COBOL binary.
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
db_reset_invoice_discounting

# Create a cost center.
create_out="$(run_cobol "IND_CREATE|IND-W16-1|ClientA|FULL|||admin@test.com")"
assert_match "IND_CREATE ok" "$create_out" "SUCCESS\|IND_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM invoice_discounting WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "IND_CREATE|IND-W16-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "IND_GET ok" "$(run_cobol "IND_GET|${id}|||||admin@test.com")" "SUCCESS\|IND_GET\|${id}\|IND-W16-1"
assert_match "IND_LIST ok" "$(run_cobol "IND_LIST|||50|0||admin@test.com")" "IND-W16-1"

# Allocate.
assert_match "IND_CALC ok" "$(run_cobol "IND_CALC|${id}|||||admin@test.com")" "SUCCESS\|IND_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM invoice_discounting WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "IND_DELETE ok" "$(run_cobol "IND_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|IND_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM invoice_discounting WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "IND_SUMMARY ok" "$(run_cobol "IND_SUMMARY||||||admin@test.com")" "SUCCESS\|IND_SUMMARY"
assert_match "IND_AUDIT ok" "$(run_cobol "IND_AUDIT|50|0||||admin@test.com")" "SUCCESS\|IND_AUDIT"
assert_match "IND_VALIDATE ok" "$(run_cobol "IND_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|IND_VALID"
assert_match "non-admin refused" "$(run_cobol "IND_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0