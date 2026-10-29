#!/usr/bin/env bash
# Research (Wave19) end-to-end DB tests via the COBOL binary.
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
db_reset_research

# Create a cost center.
create_out="$(run_cobol "RSH_CREATE|RSH-W19-1|ResearchA|MARKET|||admin@test.com")"
assert_match "RSH_CREATE ok" "$create_out" "SUCCESS\|RSH_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM research WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RSH_CREATE|RSH-W19-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RSH_GET ok" "$(run_cobol "RSH_GET|${id}|||||admin@test.com")" "SUCCESS\|RSH_GET\|${id}\|RSH-W19-1"
assert_match "RSH_LIST ok" "$(run_cobol "RSH_LIST|||50|0||admin@test.com")" "RSH-W19-1"

# Allocate.
assert_match "RSH_CALC ok" "$(run_cobol "RSH_CALC|${id}|||||admin@test.com")" "SUCCESS\|RSH_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM research WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "RSH_DELETE ok" "$(run_cobol "RSH_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|RSH_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM research WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "RSH_SUMMARY ok" "$(run_cobol "RSH_SUMMARY||||||admin@test.com")" "SUCCESS\|RSH_SUMMARY"
assert_match "RSH_AUDIT ok" "$(run_cobol "RSH_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RSH_AUDIT"
assert_match "RSH_VALIDATE ok" "$(run_cobol "RSH_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RSH_VALID"
assert_match "non-admin refused" "$(run_cobol "RSH_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0