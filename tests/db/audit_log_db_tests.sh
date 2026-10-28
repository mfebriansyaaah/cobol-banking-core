#!/usr/bin/env bash
# Audit log (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_audit_log

# Create a cost center.
create_out="$(run_cobol "ADL_CREATE|ADL-W10-1|ActorA|SYSTEM|||admin@test.com")"
assert_match "ADL_CREATE ok" "$create_out" "SUCCESS\|ADL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM audit_log WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ADL_CREATE|ADL-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ADL_GET ok" "$(run_cobol "ADL_GET|${id}|||||admin@test.com")" "SUCCESS\|ADL_GET\|${id}\|ADL-W10-1"
assert_match "ADL_LIST ok" "$(run_cobol "ADL_LIST|||50|0||admin@test.com")" "ADL-W10-1"

# Allocate.
assert_match "ADL_CALC ok" "$(run_cobol "ADL_CALC|${id}|||||admin@test.com")" "SUCCESS\|ADL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM audit_log WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ADL_DELETE ok" "$(run_cobol "ADL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ADL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM audit_log WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "ADL_SUMMARY ok" "$(run_cobol "ADL_SUMMARY||||||admin@test.com")" "SUCCESS\|ADL_SUMMARY"
assert_match "ADL_AUDIT ok" "$(run_cobol "ADL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ADL_AUDIT"
assert_match "ADL_VALIDATE ok" "$(run_cobol "ADL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ADL_VALID"
assert_match "non-admin refused" "$(run_cobol "ADL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0