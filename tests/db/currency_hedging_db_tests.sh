#!/usr/bin/env bash
# Currency hedging (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_currency_hedging

# Create a cost center.
create_out="$(run_cobol "CDH_CREATE|CDH-W9-1|EntityA|FX|||admin@test.com")"
assert_match "CDH_CREATE ok" "$create_out" "SUCCESS\|CDH_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM currency_hedging WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CDH_CREATE|CDH-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CDH_GET ok" "$(run_cobol "CDH_GET|${id}|||||admin@test.com")" "SUCCESS\|CDH_GET\|${id}\|CDH-W9-1"
assert_match "CDH_LIST ok" "$(run_cobol "CDH_LIST|||50|0||admin@test.com")" "CDH-W9-1"

# Allocate.
assert_match "CDH_CALC ok" "$(run_cobol "CDH_CALC|${id}|||||admin@test.com")" "SUCCESS\|CDH_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM currency_hedging WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CDH_DELETE ok" "$(run_cobol "CDH_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CDH_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM currency_hedging WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CDH_SUMMARY ok" "$(run_cobol "CDH_SUMMARY||||||admin@test.com")" "SUCCESS\|CDH_SUMMARY"
assert_match "CDH_AUDIT ok" "$(run_cobol "CDH_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CDH_AUDIT"
assert_match "CDH_VALIDATE ok" "$(run_cobol "CDH_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CDH_VALID"
assert_match "non-admin refused" "$(run_cobol "CDH_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0