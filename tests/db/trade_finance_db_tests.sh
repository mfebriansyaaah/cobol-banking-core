#!/usr/bin/env bash
# Trade finance (Wave3) end-to-end DB tests via the COBOL binary.
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
db_reset_trade_finance

# Create a cost center.
create_out="$(run_cobol "TRF_CREATE|TRF-W3-1|ApplicantA|LC|||admin@test.com")"
assert_match "TRF_CREATE ok" "$create_out" "SUCCESS\|TRF_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM trade_finance WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "TRF_CREATE|TRF-W3-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "TRF_GET ok" "$(run_cobol "TRF_GET|${id}|||||admin@test.com")" "SUCCESS\|TRF_GET\|${id}\|TRF-W3-1"
assert_match "TRF_LIST ok" "$(run_cobol "TRF_LIST|||50|0||admin@test.com")" "TRF-W3-1"

# Allocate.
assert_match "TRF_CALC ok" "$(run_cobol "TRF_CALC|${id}|||||admin@test.com")" "SUCCESS\|TRF_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT utilized_amount FROM trade_finance WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "TRF_DELETE ok" "$(run_cobol "TRF_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|TRF_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM trade_finance WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "TRF_SUMMARY ok" "$(run_cobol "TRF_SUMMARY||||||admin@test.com")" "SUCCESS\|TRF_SUMMARY"
assert_match "TRF_AUDIT ok" "$(run_cobol "TRF_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TRF_AUDIT"
assert_match "TRF_VALIDATE ok" "$(run_cobol "TRF_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TRF_VALID"
assert_match "non-admin refused" "$(run_cobol "TRF_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0