#!/usr/bin/env bash
# Analytics snapshot (D24) end-to-end DB tests via the COBOL binary.
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
db_reset_analytics_snapshot

# Create a cost center.
create_out="$(run_cobol "ASP_CREATE|ASP-D24-1|ReportA|ASP|||admin@test.com")"
assert_match "ASP_CREATE ok" "$create_out" "SUCCESS\|ASP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM analytics_snapshot WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ASP_CREATE|ASP-D24-1|Other|ASPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ASP_GET ok" "$(run_cobol "ASP_GET|${id}|||||admin@test.com")" "SUCCESS\|ASP_GET\|${id}\|ASP-D24-1"
assert_match "ASP_LIST ok" "$(run_cobol "ASP_LIST|||50|0||admin@test.com")" "ASP-D24-1"

# Allocate.
assert_match "ASP_CALC ok" "$(run_cobol "ASP_CALC|${id}|||||admin@test.com")" "SUCCESS\|ASP_CALC\|1"
assert_match "posted persisted" "$(db_query "SELECT refreshed_count FROM analytics_snapshot WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ASP_DELETE ok" "$(run_cobol "ASP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ASP_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM analytics_snapshot WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "ASP_SUMMARY ok" "$(run_cobol "ASP_SUMMARY||||||admin@test.com")" "SUCCESS\|ASP_SUMMARY"
assert_match "ASP_AUDIT ok" "$(run_cobol "ASP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ASP_AUDIT"
assert_match "ASP_VALIDATE ok" "$(run_cobol "ASP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ASP_VALID"
assert_match "non-admin refused" "$(run_cobol "ASP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0