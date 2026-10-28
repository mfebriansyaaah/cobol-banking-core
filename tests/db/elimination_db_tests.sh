#!/usr/bin/env bash
# Elimination (Wave14) end-to-end DB tests via the COBOL binary.
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
db_reset_elimination

# Create a cost center.
create_out="$(run_cobol "ELM_CREATE|ELM-W14-1|ElimA|INTERCO|||admin@test.com")"
assert_match "ELM_CREATE ok" "$create_out" "SUCCESS\|ELM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM elimination WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ELM_CREATE|ELM-W14-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ELM_GET ok" "$(run_cobol "ELM_GET|${id}|||||admin@test.com")" "SUCCESS\|ELM_GET\|${id}\|ELM-W14-1"
assert_match "ELM_LIST ok" "$(run_cobol "ELM_LIST|||50|0||admin@test.com")" "ELM-W14-1"

# Allocate.
assert_match "ELM_CALC ok" "$(run_cobol "ELM_CALC|${id}|||||admin@test.com")" "SUCCESS\|ELM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM elimination WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ELM_DELETE ok" "$(run_cobol "ELM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ELM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM elimination WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "ELM_SUMMARY ok" "$(run_cobol "ELM_SUMMARY||||||admin@test.com")" "SUCCESS\|ELM_SUMMARY"
assert_match "ELM_AUDIT ok" "$(run_cobol "ELM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ELM_AUDIT"
assert_match "ELM_VALIDATE ok" "$(run_cobol "ELM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ELM_VALID"
assert_match "non-admin refused" "$(run_cobol "ELM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0