#!/usr/bin/env bash
# Name screening (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_name_screening

# Create a cost center.
create_out="$(run_cobol "NSC_CREATE|NSC-W8-1|EntityA|FUZZY|||admin@test.com")"
assert_match "NSC_CREATE ok" "$create_out" "SUCCESS\|NSC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM name_screening WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "NSC_CREATE|NSC-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "NSC_GET ok" "$(run_cobol "NSC_GET|${id}|||||admin@test.com")" "SUCCESS\|NSC_GET\|${id}\|NSC-W8-1"
assert_match "NSC_LIST ok" "$(run_cobol "NSC_LIST|||50|0||admin@test.com")" "NSC-W8-1"

# Allocate.
assert_match "NSC_CALC ok" "$(run_cobol "NSC_CALC|${id}|||||admin@test.com")" "SUCCESS\|NSC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM name_screening WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "NSC_DELETE ok" "$(run_cobol "NSC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|NSC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM name_screening WHERE id=${id};")" "^FLAGGED$"

# Summary and audit.
assert_match "NSC_SUMMARY ok" "$(run_cobol "NSC_SUMMARY||||||admin@test.com")" "SUCCESS\|NSC_SUMMARY"
assert_match "NSC_AUDIT ok" "$(run_cobol "NSC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|NSC_AUDIT"
assert_match "NSC_VALIDATE ok" "$(run_cobol "NSC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|NSC_VALID"
assert_match "non-admin refused" "$(run_cobol "NSC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0