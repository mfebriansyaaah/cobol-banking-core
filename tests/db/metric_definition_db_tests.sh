#!/usr/bin/env bash
# Metric definition (D23) end-to-end DB tests via the COBOL binary.
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
db_reset_metric_definition

# Create a cost center.
create_out="$(run_cobol "MDF_CREATE|MDF-D23-1|MetricA|MDF|||admin@test.com")"
assert_match "MDF_CREATE ok" "$create_out" "SUCCESS\|MDF_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM metric_definition WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MDF_CREATE|MDF-D23-1|Other|MDFEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MDF_GET ok" "$(run_cobol "MDF_GET|${id}|||||admin@test.com")" "SUCCESS\|MDF_GET\|${id}\|MDF-D23-1"
assert_match "MDF_LIST ok" "$(run_cobol "MDF_LIST|||50|0||admin@test.com")" "MDF-D23-1"

# Allocate.
assert_match "MDF_CALC ok" "$(run_cobol "MDF_CALC|${id}|||||admin@test.com")" "SUCCESS\|MDF_CALC\|1"
assert_match "posted persisted" "$(db_query "SELECT actual_value FROM metric_definition WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MDF_DELETE ok" "$(run_cobol "MDF_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MDF_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM metric_definition WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "MDF_SUMMARY ok" "$(run_cobol "MDF_SUMMARY||||||admin@test.com")" "SUCCESS\|MDF_SUMMARY"
assert_match "MDF_AUDIT ok" "$(run_cobol "MDF_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MDF_AUDIT"
assert_match "MDF_VALIDATE ok" "$(run_cobol "MDF_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MDF_VALID"
assert_match "non-admin refused" "$(run_cobol "MDF_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0