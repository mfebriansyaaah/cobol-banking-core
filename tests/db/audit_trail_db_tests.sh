#!/usr/bin/env bash
# Audit trail (Wave5) end-to-end DB tests via the COBOL binary.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
if ! db_available; then echo "SKIP: DB unavailable"; exit 0; fi

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

db_seed
db_reset_adt_log

# Create a cost center.
create_out="$(run_cobol "ADT_CREATE|ADT-W5-1|AuditA|SECURITY|||admin@test.com")"
assert_match "ADT_CREATE ok" "$create_out" "SUCCESS\|ADT_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM adt_log WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ADT_CREATE|ADT-W5-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ADT_GET ok" "$(run_cobol "ADT_GET|${id}|||||admin@test.com")" "SUCCESS\|ADT_GET\|${id}\|ADT-W5-1"
assert_match "ADT_LIST ok" "$(run_cobol "ADT_LIST|||50|0||admin@test.com")" "ADT-W5-1"

# Allocate.
assert_match "ADT_CALC ok" "$(run_cobol "ADT_CALC|${id}|||||admin@test.com")" "SUCCESS\|ADT_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT entry_count FROM adt_log WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ADT_DELETE ok" "$(run_cobol "ADT_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ADT_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM adt_log WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "ADT_SUMMARY ok" "$(run_cobol "ADT_SUMMARY||||||admin@test.com")" "SUCCESS\|ADT_SUMMARY"
assert_match "ADT_AUDIT ok" "$(run_cobol "ADT_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ADT_AUDIT"
assert_match "ADT_VALIDATE ok" "$(run_cobol "ADT_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ADT_VALID"
assert_match "non-admin refused" "$(run_cobol "ADT_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0