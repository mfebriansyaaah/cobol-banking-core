#!/usr/bin/env bash
# Syndicated loan (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_syndicated_loan

# Create a cost center.
create_out="$(run_cobol "SYL_CREATE|SYL-W6-1|BorrowerA|TERM|||admin@test.com")"
assert_match "SYL_CREATE ok" "$create_out" "SUCCESS\|SYL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM syndicated_loan WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SYL_CREATE|SYL-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SYL_GET ok" "$(run_cobol "SYL_GET|${id}|||||admin@test.com")" "SUCCESS\|SYL_GET\|${id}\|SYL-W6-1"
assert_match "SYL_LIST ok" "$(run_cobol "SYL_LIST|||50|0||admin@test.com")" "SYL-W6-1"

# Allocate.
assert_match "SYL_CALC ok" "$(run_cobol "SYL_CALC|${id}|||||admin@test.com")" "SUCCESS\|SYL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM syndicated_loan WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SYL_DELETE ok" "$(run_cobol "SYL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SYL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM syndicated_loan WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "SYL_SUMMARY ok" "$(run_cobol "SYL_SUMMARY||||||admin@test.com")" "SUCCESS\|SYL_SUMMARY"
assert_match "SYL_AUDIT ok" "$(run_cobol "SYL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SYL_AUDIT"
assert_match "SYL_VALIDATE ok" "$(run_cobol "SYL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SYL_VALID"
assert_match "non-admin refused" "$(run_cobol "SYL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"




# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM syndicated_loan WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM syndicated_loan_audit WHERE syndicated_loan_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "SYL_UPDATE|${id}|BorrowerA|TERM|||admin@test.com")"
assert_match "SYL_UPDATE ok" "$upd_out" "SUCCESS\\|SYL_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM syndicated_loan WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM syndicated_loan_audit WHERE syndicated_loan_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "SYL_UPDATE|999999|BorrowerA|TERM|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "SYL_UPDATE|${id}|BorrowerA|TERM|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0