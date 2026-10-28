#!/usr/bin/env bash
# Option trading (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_option_trading

# Create a cost center.
create_out="$(run_cobol "OPT_CREATE|OPT-W6-1|HolderA|CALL|||admin@test.com")"
assert_match "OPT_CREATE ok" "$create_out" "SUCCESS\|OPT_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM option_trading WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "OPT_CREATE|OPT-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "OPT_GET ok" "$(run_cobol "OPT_GET|${id}|||||admin@test.com")" "SUCCESS\|OPT_GET\|${id}\|OPT-W6-1"
assert_match "OPT_LIST ok" "$(run_cobol "OPT_LIST|||50|0||admin@test.com")" "OPT-W6-1"

# Allocate.
assert_match "OPT_CALC ok" "$(run_cobol "OPT_CALC|${id}|||||admin@test.com")" "SUCCESS\|OPT_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM option_trading WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "OPT_DELETE ok" "$(run_cobol "OPT_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|OPT_DELETE"
assert_match "expired persisted" "$(db_query "SELECT status FROM option_trading WHERE id=${id};")" "^EXPIRED$"

# Summary and audit.
assert_match "OPT_SUMMARY ok" "$(run_cobol "OPT_SUMMARY||||||admin@test.com")" "SUCCESS\|OPT_SUMMARY"
assert_match "OPT_AUDIT ok" "$(run_cobol "OPT_AUDIT|50|0||||admin@test.com")" "SUCCESS\|OPT_AUDIT"
assert_match "OPT_VALIDATE ok" "$(run_cobol "OPT_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|OPT_VALID"
assert_match "non-admin refused" "$(run_cobol "OPT_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0