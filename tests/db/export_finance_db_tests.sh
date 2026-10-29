#!/usr/bin/env bash
# Export finance (Wave16) end-to-end DB tests via the COBOL binary.
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
db_reset_export_finance

# Create a cost center.
create_out="$(run_cobol "EXF_CREATE|EXF-W16-1|ExporterA|PRE_SHIPMENT|||admin@test.com")"
assert_match "EXF_CREATE ok" "$create_out" "SUCCESS\|EXF_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM export_finance WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "EXF_CREATE|EXF-W16-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "EXF_GET ok" "$(run_cobol "EXF_GET|${id}|||||admin@test.com")" "SUCCESS\|EXF_GET\|${id}\|EXF-W16-1"
assert_match "EXF_LIST ok" "$(run_cobol "EXF_LIST|||50|0||admin@test.com")" "EXF-W16-1"

# Allocate.
assert_match "EXF_CALC ok" "$(run_cobol "EXF_CALC|${id}|||||admin@test.com")" "SUCCESS\|EXF_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM export_finance WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "EXF_DELETE ok" "$(run_cobol "EXF_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|EXF_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM export_finance WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "EXF_SUMMARY ok" "$(run_cobol "EXF_SUMMARY||||||admin@test.com")" "SUCCESS\|EXF_SUMMARY"
assert_match "EXF_AUDIT ok" "$(run_cobol "EXF_AUDIT|50|0||||admin@test.com")" "SUCCESS\|EXF_AUDIT"
assert_match "EXF_VALIDATE ok" "$(run_cobol "EXF_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|EXF_VALID"
assert_match "non-admin refused" "$(run_cobol "EXF_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0