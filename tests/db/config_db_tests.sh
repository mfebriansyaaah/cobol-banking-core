#!/usr/bin/env bash
# Config (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_config

# Create a cost center.
create_out="$(run_cobol "CFG_CREATE|CFG-W11-1|ConfigA|APP|||admin@test.com")"
assert_match "CFG_CREATE ok" "$create_out" "SUCCESS\|CFG_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM config WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CFG_CREATE|CFG-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CFG_GET ok" "$(run_cobol "CFG_GET|${id}|||||admin@test.com")" "SUCCESS\|CFG_GET\|${id}\|CFG-W11-1"
assert_match "CFG_LIST ok" "$(run_cobol "CFG_LIST|||50|0||admin@test.com")" "CFG-W11-1"

# Allocate.
assert_match "CFG_CALC ok" "$(run_cobol "CFG_CALC|${id}|||||admin@test.com")" "SUCCESS\|CFG_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM config WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CFG_DELETE ok" "$(run_cobol "CFG_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CFG_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM config WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CFG_SUMMARY ok" "$(run_cobol "CFG_SUMMARY||||||admin@test.com")" "SUCCESS\|CFG_SUMMARY"
assert_match "CFG_AUDIT ok" "$(run_cobol "CFG_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CFG_AUDIT"
assert_match "CFG_VALIDATE ok" "$(run_cobol "CFG_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CFG_VALID"
assert_match "non-admin refused" "$(run_cobol "CFG_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0