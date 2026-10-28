#!/usr/bin/env bash
# Account statement (Wave13) end-to-end DB tests via the COBOL binary.
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
db_reset_account_statement

# Create a cost center.
create_out="$(run_cobol "STMTS_CREATE|STMTS-W13-1|AccountA|MONTHLY|||admin@test.com")"
assert_match "STMTS_CREATE ok" "$create_out" "SUCCESS\|STMTS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM account_statement WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "STMTS_CREATE|STMTS-W13-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "STMTS_GET ok" "$(run_cobol "STMTS_GET|${id}|||||admin@test.com")" "SUCCESS\|STMTS_GET\|${id}\|STMTS-W13-1"
assert_match "STMTS_LIST ok" "$(run_cobol "STMTS_LIST|||50|0||admin@test.com")" "STMTS-W13-1"

# Allocate.
assert_match "STMTS_CALC ok" "$(run_cobol "STMTS_CALC|${id}|||||admin@test.com")" "SUCCESS\|STMTS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM account_statement WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "STMTS_DELETE ok" "$(run_cobol "STMTS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|STMTS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM account_statement WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "STMTS_SUMMARY ok" "$(run_cobol "STMTS_SUMMARY||||||admin@test.com")" "SUCCESS\|STMTS_SUMMARY"
assert_match "STMTS_AUDIT ok" "$(run_cobol "STMTS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|STMTS_AUDIT"
assert_match "STMTS_VALIDATE ok" "$(run_cobol "STMTS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|STMTS_VALID"
assert_match "non-admin refused" "$(run_cobol "STMTS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0