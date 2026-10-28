#!/usr/bin/env bash
# ETF (Wave12) end-to-end DB tests via the COBOL binary.
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
db_reset_etf

# Create a cost center.
create_out="$(run_cobol "ETF_CREATE|ETF-W12-1|EtfA|INDEX|||admin@test.com")"
assert_match "ETF_CREATE ok" "$create_out" "SUCCESS\|ETF_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM etf WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ETF_CREATE|ETF-W12-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ETF_GET ok" "$(run_cobol "ETF_GET|${id}|||||admin@test.com")" "SUCCESS\|ETF_GET\|${id}\|ETF-W12-1"
assert_match "ETF_LIST ok" "$(run_cobol "ETF_LIST|||50|0||admin@test.com")" "ETF-W12-1"

# Allocate.
assert_match "ETF_CALC ok" "$(run_cobol "ETF_CALC|${id}|||||admin@test.com")" "SUCCESS\|ETF_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM etf WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ETF_DELETE ok" "$(run_cobol "ETF_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ETF_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM etf WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "ETF_SUMMARY ok" "$(run_cobol "ETF_SUMMARY||||||admin@test.com")" "SUCCESS\|ETF_SUMMARY"
assert_match "ETF_AUDIT ok" "$(run_cobol "ETF_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ETF_AUDIT"
assert_match "ETF_VALIDATE ok" "$(run_cobol "ETF_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ETF_VALID"
assert_match "non-admin refused" "$(run_cobol "ETF_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0