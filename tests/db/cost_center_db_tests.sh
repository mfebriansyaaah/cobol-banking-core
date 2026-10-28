#!/usr/bin/env bash
# Cost center (D14) end-to-end DB tests via the COBOL binary.
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
db_reset_cost_center

# Create a cost center.
create_out="$(run_cobol "CSC_CREATE|CSC-D14-1|Engineering|OPEX|||admin@test.com")"
assert_match "CSC_CREATE ok" "$create_out" "SUCCESS\|CSC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM cost_center WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CSC_CREATE|CSC-D14-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CSC_GET ok" "$(run_cobol "CSC_GET|${id}|||||admin@test.com")" "SUCCESS\|CSC_GET\|${id}\|CSC-D14-1"
assert_match "CSC_LIST ok" "$(run_cobol "CSC_LIST||OPEX|50|0||admin@test.com")" "CSC-D14-1"

# Allocate.
assert_match "CSC_ALLO ok" "$(run_cobol "CSC_ALLO|${id}|||||admin@test.com")" "SUCCESS\|CSC_ALLO\|1"
assert_match "budget persisted" "$(db_query "SELECT budget_amount FROM cost_center WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CSC_CLOSE ok" "$(run_cobol "CSC_CLOSE|${id}|Budget used||||admin@test.com")" "SUCCESS\|CSC_CLOSE"
assert_match "closed persisted" "$(db_query "SELECT status FROM cost_center WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CSC_SUMMARY ok" "$(run_cobol "CSC_SUMMARY||||||admin@test.com")" "SUCCESS\|CSC_SUMMARY"
assert_match "CSC_AUDIT ok" "$(run_cobol "CSC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CSC_AUDIT"
assert_match "CSC_VALIDATE ok" "$(run_cobol "CSC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CSC_VALID"
assert_match "non-admin refused" "$(run_cobol "CSC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0