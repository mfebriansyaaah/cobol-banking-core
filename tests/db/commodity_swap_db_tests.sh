#!/usr/bin/env bash
# Commodity swap (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_commodity_swap

# Create a cost center.
create_out="$(run_cobol "CMS_CREATE|CMS-W9-1|CounterpartyA|COMMODITY|||admin@test.com")"
assert_match "CMS_CREATE ok" "$create_out" "SUCCESS\|CMS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM commodity_swap WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CMS_CREATE|CMS-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CMS_GET ok" "$(run_cobol "CMS_GET|${id}|||||admin@test.com")" "SUCCESS\|CMS_GET\|${id}\|CMS-W9-1"
assert_match "CMS_LIST ok" "$(run_cobol "CMS_LIST|||50|0||admin@test.com")" "CMS-W9-1"

# Allocate.
assert_match "CMS_CALC ok" "$(run_cobol "CMS_CALC|${id}|||||admin@test.com")" "SUCCESS\|CMS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM commodity_swap WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CMS_DELETE ok" "$(run_cobol "CMS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CMS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM commodity_swap WHERE id=${id};")" "^MATURED$"

# Summary and audit.
assert_match "CMS_SUMMARY ok" "$(run_cobol "CMS_SUMMARY||||||admin@test.com")" "SUCCESS\|CMS_SUMMARY"
assert_match "CMS_AUDIT ok" "$(run_cobol "CMS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CMS_AUDIT"
assert_match "CMS_VALIDATE ok" "$(run_cobol "CMS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CMS_VALID"
assert_match "non-admin refused" "$(run_cobol "CMS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0