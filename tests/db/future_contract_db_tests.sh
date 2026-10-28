#!/usr/bin/env bash
# Future contract (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_future_contract

# Create a cost center.
create_out="$(run_cobol "FTC_CREATE|FTC-W6-1|TraderA|INDEX|||admin@test.com")"
assert_match "FTC_CREATE ok" "$create_out" "SUCCESS\|FTC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM future_contract WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "FTC_CREATE|FTC-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "FTC_GET ok" "$(run_cobol "FTC_GET|${id}|||||admin@test.com")" "SUCCESS\|FTC_GET\|${id}\|FTC-W6-1"
assert_match "FTC_LIST ok" "$(run_cobol "FTC_LIST|||50|0||admin@test.com")" "FTC-W6-1"

# Allocate.
assert_match "FTC_CALC ok" "$(run_cobol "FTC_CALC|${id}|||||admin@test.com")" "SUCCESS\|FTC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM future_contract WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "FTC_DELETE ok" "$(run_cobol "FTC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|FTC_DELETE"
assert_match "settled persisted" "$(db_query "SELECT status FROM future_contract WHERE id=${id};")" "^SETTLED$"

# Summary and audit.
assert_match "FTC_SUMMARY ok" "$(run_cobol "FTC_SUMMARY||||||admin@test.com")" "SUCCESS\|FTC_SUMMARY"
assert_match "FTC_AUDIT ok" "$(run_cobol "FTC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|FTC_AUDIT"
assert_match "FTC_VALIDATE ok" "$(run_cobol "FTC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|FTC_VALID"
assert_match "non-admin refused" "$(run_cobol "FTC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0