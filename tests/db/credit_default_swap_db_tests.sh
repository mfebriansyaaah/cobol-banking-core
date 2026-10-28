#!/usr/bin/env bash
# Credit default swap (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_credit_default_swap

# Create a cost center.
create_out="$(run_cobol "CDS_CREATE|CDS-W9-1|CounterpartyA|CDS|||admin@test.com")"
assert_match "CDS_CREATE ok" "$create_out" "SUCCESS\|CDS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM credit_default_swap WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CDS_CREATE|CDS-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CDS_GET ok" "$(run_cobol "CDS_GET|${id}|||||admin@test.com")" "SUCCESS\|CDS_GET\|${id}\|CDS-W9-1"
assert_match "CDS_LIST ok" "$(run_cobol "CDS_LIST|||50|0||admin@test.com")" "CDS-W9-1"

# Allocate.
assert_match "CDS_CALC ok" "$(run_cobol "CDS_CALC|${id}|||||admin@test.com")" "SUCCESS\|CDS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM credit_default_swap WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CDS_DELETE ok" "$(run_cobol "CDS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CDS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM credit_default_swap WHERE id=${id};")" "^MATURED$"

# Summary and audit.
assert_match "CDS_SUMMARY ok" "$(run_cobol "CDS_SUMMARY||||||admin@test.com")" "SUCCESS\|CDS_SUMMARY"
assert_match "CDS_AUDIT ok" "$(run_cobol "CDS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CDS_AUDIT"
assert_match "CDS_VALIDATE ok" "$(run_cobol "CDS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CDS_VALID"
assert_match "non-admin refused" "$(run_cobol "CDS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0