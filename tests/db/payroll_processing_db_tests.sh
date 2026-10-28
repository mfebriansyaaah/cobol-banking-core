#!/usr/bin/env bash
# Payroll processing (Wave4) end-to-end DB tests via the COBOL binary.
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
db_reset_payroll_processing

# Create a cost center.
create_out="$(run_cobol "PRL_CREATE|PRL-W4-1|BatchA|MONTHLY|||admin@test.com")"
assert_match "PRL_CREATE ok" "$create_out" "SUCCESS\|PRL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM payroll_processing WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PRL_CREATE|PRL-W4-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PRL_GET ok" "$(run_cobol "PRL_GET|${id}|||||admin@test.com")" "SUCCESS\|PRL_GET\|${id}\|PRL-W4-1"
assert_match "PRL_LIST ok" "$(run_cobol "PRL_LIST|||50|0||admin@test.com")" "PRL-W4-1"

# Allocate.
assert_match "PRL_CALC ok" "$(run_cobol "PRL_CALC|${id}|||||admin@test.com")" "SUCCESS\|PRL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT processed_amount FROM payroll_processing WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PRL_DELETE ok" "$(run_cobol "PRL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PRL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM payroll_processing WHERE id=${id};")" "^COMPLETED$"

# Summary and audit.
assert_match "PRL_SUMMARY ok" "$(run_cobol "PRL_SUMMARY||||||admin@test.com")" "SUCCESS\|PRL_SUMMARY"
assert_match "PRL_AUDIT ok" "$(run_cobol "PRL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PRL_AUDIT"
assert_match "PRL_VALIDATE ok" "$(run_cobol "PRL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PRL_VALID"
assert_match "non-admin refused" "$(run_cobol "PRL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0