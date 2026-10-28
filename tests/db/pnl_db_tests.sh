#!/usr/bin/env bash
# PnL (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_pnl

# Create a cost center.
create_out="$(run_cobol "PNL_CREATE|PNL-W9-1|EntityA|DAILY|||admin@test.com")"
assert_match "PNL_CREATE ok" "$create_out" "SUCCESS\|PNL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM pnl WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PNL_CREATE|PNL-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PNL_GET ok" "$(run_cobol "PNL_GET|${id}|||||admin@test.com")" "SUCCESS\|PNL_GET\|${id}\|PNL-W9-1"
assert_match "PNL_LIST ok" "$(run_cobol "PNL_LIST|||50|0||admin@test.com")" "PNL-W9-1"

# Allocate.
assert_match "PNL_CALC ok" "$(run_cobol "PNL_CALC|${id}|||||admin@test.com")" "SUCCESS\|PNL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM pnl WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PNL_DELETE ok" "$(run_cobol "PNL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PNL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM pnl WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PNL_SUMMARY ok" "$(run_cobol "PNL_SUMMARY||||||admin@test.com")" "SUCCESS\|PNL_SUMMARY"
assert_match "PNL_AUDIT ok" "$(run_cobol "PNL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PNL_AUDIT"
assert_match "PNL_VALIDATE ok" "$(run_cobol "PNL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PNL_VALID"
assert_match "non-admin refused" "$(run_cobol "PNL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0