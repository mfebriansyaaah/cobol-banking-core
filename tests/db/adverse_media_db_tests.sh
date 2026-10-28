#!/usr/bin/env bash
# Adverse media (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_adverse_media

# Create a cost center.
create_out="$(run_cobol "ADM_CREATE|ADM-W8-1|EntityA|NEWS|||admin@test.com")"
assert_match "ADM_CREATE ok" "$create_out" "SUCCESS\|ADM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM adverse_media WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ADM_CREATE|ADM-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ADM_GET ok" "$(run_cobol "ADM_GET|${id}|||||admin@test.com")" "SUCCESS\|ADM_GET\|${id}\|ADM-W8-1"
assert_match "ADM_LIST ok" "$(run_cobol "ADM_LIST|||50|0||admin@test.com")" "ADM-W8-1"

# Allocate.
assert_match "ADM_CALC ok" "$(run_cobol "ADM_CALC|${id}|||||admin@test.com")" "SUCCESS\|ADM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM adverse_media WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ADM_DELETE ok" "$(run_cobol "ADM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ADM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM adverse_media WHERE id=${id};")" "^FLAGGED$"

# Summary and audit.
assert_match "ADM_SUMMARY ok" "$(run_cobol "ADM_SUMMARY||||||admin@test.com")" "SUCCESS\|ADM_SUMMARY"
assert_match "ADM_AUDIT ok" "$(run_cobol "ADM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ADM_AUDIT"
assert_match "ADM_VALIDATE ok" "$(run_cobol "ADM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ADM_VALID"
assert_match "non-admin refused" "$(run_cobol "ADM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0