#!/usr/bin/env bash
# Liability (Wave13) end-to-end DB tests via the COBOL binary.
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
db_reset_liability

# Create a cost center.
create_out="$(run_cobol "LIA_CREATE|LIA-W13-1|EntityA|CURRENT|||admin@test.com")"
assert_match "LIA_CREATE ok" "$create_out" "SUCCESS\|LIA_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM liability WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "LIA_CREATE|LIA-W13-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "LIA_GET ok" "$(run_cobol "LIA_GET|${id}|||||admin@test.com")" "SUCCESS\|LIA_GET\|${id}\|LIA-W13-1"
assert_match "LIA_LIST ok" "$(run_cobol "LIA_LIST|||50|0||admin@test.com")" "LIA-W13-1"

# Allocate.
assert_match "LIA_CALC ok" "$(run_cobol "LIA_CALC|${id}|||||admin@test.com")" "SUCCESS\|LIA_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM liability WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "LIA_DELETE ok" "$(run_cobol "LIA_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|LIA_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM liability WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "LIA_SUMMARY ok" "$(run_cobol "LIA_SUMMARY||||||admin@test.com")" "SUCCESS\|LIA_SUMMARY"
assert_match "LIA_AUDIT ok" "$(run_cobol "LIA_AUDIT|50|0||||admin@test.com")" "SUCCESS\|LIA_AUDIT"
assert_match "LIA_VALIDATE ok" "$(run_cobol "LIA_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|LIA_VALID"
assert_match "non-admin refused" "$(run_cobol "LIA_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0