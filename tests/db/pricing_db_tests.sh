#!/usr/bin/env bash
# Pricing (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_pricing

# Create a cost center.
create_out="$(run_cobol "PRG_CREATE|PRG-W9-1|EntityA|MODEL|||admin@test.com")"
assert_match "PRG_CREATE ok" "$create_out" "SUCCESS\|PRG_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM pricing WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PRG_CREATE|PRG-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PRG_GET ok" "$(run_cobol "PRG_GET|${id}|||||admin@test.com")" "SUCCESS\|PRG_GET\|${id}\|PRG-W9-1"
assert_match "PRG_LIST ok" "$(run_cobol "PRG_LIST|||50|0||admin@test.com")" "PRG-W9-1"

# Allocate.
assert_match "PRG_CALC ok" "$(run_cobol "PRG_CALC|${id}|||||admin@test.com")" "SUCCESS\|PRG_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM pricing WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PRG_DELETE ok" "$(run_cobol "PRG_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PRG_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM pricing WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PRG_SUMMARY ok" "$(run_cobol "PRG_SUMMARY||||||admin@test.com")" "SUCCESS\|PRG_SUMMARY"
assert_match "PRG_AUDIT ok" "$(run_cobol "PRG_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PRG_AUDIT"
assert_match "PRG_VALIDATE ok" "$(run_cobol "PRG_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PRG_VALID"
assert_match "non-admin refused" "$(run_cobol "PRG_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0