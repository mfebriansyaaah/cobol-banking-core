#!/usr/bin/env bash
# External audit (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_external_audit

# Create a cost center.
create_out="$(run_cobol "EXA_CREATE|EXA-W7-1|AuditA|FINANCIAL|||admin@test.com")"
assert_match "EXA_CREATE ok" "$create_out" "SUCCESS\|EXA_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM external_audit WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "EXA_CREATE|EXA-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "EXA_GET ok" "$(run_cobol "EXA_GET|${id}|||||admin@test.com")" "SUCCESS\|EXA_GET\|${id}\|EXA-W7-1"
assert_match "EXA_LIST ok" "$(run_cobol "EXA_LIST|||50|0||admin@test.com")" "EXA-W7-1"

# Allocate.
assert_match "EXA_CALC ok" "$(run_cobol "EXA_CALC|${id}|||||admin@test.com")" "SUCCESS\|EXA_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM external_audit WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "EXA_DELETE ok" "$(run_cobol "EXA_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|EXA_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM external_audit WHERE id=${id};")" "^COMPLETED$"

# Summary and audit.
assert_match "EXA_SUMMARY ok" "$(run_cobol "EXA_SUMMARY||||||admin@test.com")" "SUCCESS\|EXA_SUMMARY"
assert_match "EXA_AUDIT ok" "$(run_cobol "EXA_AUDIT|50|0||||admin@test.com")" "SUCCESS\|EXA_AUDIT"
assert_match "EXA_VALIDATE ok" "$(run_cobol "EXA_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|EXA_VALID"
assert_match "non-admin refused" "$(run_cobol "EXA_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0