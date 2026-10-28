#!/usr/bin/env bash
# Dashboard widget (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_dashboard_widget

# Create a cost center.
create_out="$(run_cobol "DSW_CREATE|DSW-W10-1|WidgetA|CHART|||admin@test.com")"
assert_match "DSW_CREATE ok" "$create_out" "SUCCESS\|DSW_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM dashboard_widget WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DSW_CREATE|DSW-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DSW_GET ok" "$(run_cobol "DSW_GET|${id}|||||admin@test.com")" "SUCCESS\|DSW_GET\|${id}\|DSW-W10-1"
assert_match "DSW_LIST ok" "$(run_cobol "DSW_LIST|||50|0||admin@test.com")" "DSW-W10-1"

# Allocate.
assert_match "DSW_CALC ok" "$(run_cobol "DSW_CALC|${id}|||||admin@test.com")" "SUCCESS\|DSW_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM dashboard_widget WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DSW_DELETE ok" "$(run_cobol "DSW_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|DSW_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM dashboard_widget WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "DSW_SUMMARY ok" "$(run_cobol "DSW_SUMMARY||||||admin@test.com")" "SUCCESS\|DSW_SUMMARY"
assert_match "DSW_AUDIT ok" "$(run_cobol "DSW_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DSW_AUDIT"
assert_match "DSW_VALIDATE ok" "$(run_cobol "DSW_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DSW_VALID"
assert_match "non-admin refused" "$(run_cobol "DSW_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0