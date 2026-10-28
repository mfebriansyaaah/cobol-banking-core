#!/usr/bin/env bash
# D10 (Data/Reporting) end-to-end DB tests via the COBOL binary.
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
db_reset_report_builder

# Create a report.
create_out="$(run_cobol "RPB_CREATE|RPB-D10-1|Sales Report|MONTHLY|||admin@test.com")"
assert_match "RPB_CREATE ok" "$create_out" "SUCCESS\|RPB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM report_builder WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RPB_CREATE|RPB-D10-1|Other|WEEKLY|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RPB_GET ok" "$(run_cobol "RPB_GET|${id}|||||admin@test.com")" "SUCCESS\|RPB_GET\|${id}\|RPB-D10-1"
assert_match "RPB_LIST ok" "$(run_cobol "RPB_LIST||MONTHLY|50|0||admin@test.com")" "RPB-D10-1"

# Run.
assert_match "RPB_RUN ok" "$(run_cobol "RPB_RUN|${id}|||||admin@test.com")" "SUCCESS\|RPB_RUN\|1"
assert_match "run_count persisted" "$(db_query "SELECT run_count FROM report_builder WHERE id=${id};")" "^1$"

# Close.
assert_match "RPB_CLOSE ok" "$(run_cobol "RPB_CLOSE|${id}|Completed||||admin@test.com")" "SUCCESS\|RPB_CLOSE"
assert_match "closed persisted" "$(db_query "SELECT status FROM report_builder WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "RPB_SUMMARY ok" "$(run_cobol "RPB_SUMMARY||||||admin@test.com")" "SUCCESS\|RPB_SUMMARY"
assert_match "RPB_AUDIT ok" "$(run_cobol "RPB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RPB_AUDIT"
assert_match "RPB_VALIDATE ok" "$(run_cobol "RPB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RPB_VALID"
assert_match "non-admin refused" "$(run_cobol "RPB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0