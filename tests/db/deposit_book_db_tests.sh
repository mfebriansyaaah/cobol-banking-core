#!/usr/bin/env bash
# Deposit book (Wave15) end-to-end DB tests via the COBOL binary.
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
db_reset_deposit_book

# Create a cost center.
create_out="$(run_cobol "DEPS_CREATE|DEPS-W15-1|DepositorA|SAVINGS|||admin@test.com")"
assert_match "DEPS_CREATE ok" "$create_out" "SUCCESS\|DEPS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM deposit_book WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DEPS_CREATE|DEPS-W15-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DEPS_GET ok" "$(run_cobol "DEPS_GET|${id}|||||admin@test.com")" "SUCCESS\|DEPS_GET\|${id}\|DEPS-W15-1"
assert_match "DEPS_LIST ok" "$(run_cobol "DEPS_LIST|||50|0||admin@test.com")" "DEPS-W15-1"

# Allocate.
assert_match "DEPS_CALC ok" "$(run_cobol "DEPS_CALC|${id}|||||admin@test.com")" "SUCCESS\|DEPS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM deposit_book WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DEPS_DELETE ok" "$(run_cobol "DEPS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|DEPS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM deposit_book WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "DEPS_SUMMARY ok" "$(run_cobol "DEPS_SUMMARY||||||admin@test.com")" "SUCCESS\|DEPS_SUMMARY"
assert_match "DEPS_AUDIT ok" "$(run_cobol "DEPS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DEPS_AUDIT"
assert_match "DEPS_VALIDATE ok" "$(run_cobol "DEPS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DEPS_VALID"
assert_match "non-admin refused" "$(run_cobol "DEPS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0