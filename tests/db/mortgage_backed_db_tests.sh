#!/usr/bin/env bash
# Mortgage backed (Wave12) end-to-end DB tests via the COBOL binary.
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
db_reset_mortgage_backed

# Create a cost center.
create_out="$(run_cobol "MBS_CREATE|MBS-W12-1|MortgageA|RMBS|||admin@test.com")"
assert_match "MBS_CREATE ok" "$create_out" "SUCCESS\|MBS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM mortgage_backed WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MBS_CREATE|MBS-W12-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MBS_GET ok" "$(run_cobol "MBS_GET|${id}|||||admin@test.com")" "SUCCESS\|MBS_GET\|${id}\|MBS-W12-1"
assert_match "MBS_LIST ok" "$(run_cobol "MBS_LIST|||50|0||admin@test.com")" "MBS-W12-1"

# Allocate.
assert_match "MBS_CALC ok" "$(run_cobol "MBS_CALC|${id}|||||admin@test.com")" "SUCCESS\|MBS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM mortgage_backed WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MBS_DELETE ok" "$(run_cobol "MBS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MBS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM mortgage_backed WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "MBS_SUMMARY ok" "$(run_cobol "MBS_SUMMARY||||||admin@test.com")" "SUCCESS\|MBS_SUMMARY"
assert_match "MBS_AUDIT ok" "$(run_cobol "MBS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MBS_AUDIT"
assert_match "MBS_VALIDATE ok" "$(run_cobol "MBS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MBS_VALID"
assert_match "non-admin refused" "$(run_cobol "MBS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM mortgage_backed WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM mortgage_backed_audit WHERE mortgage_backed_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "MBS_UPDATE|${id}|MortgageA|RMBS|||admin@test.com")"
assert_match "MBS_UPDATE ok" "$upd_out" "SUCCESS\\|MBS_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM mortgage_backed WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM mortgage_backed_audit WHERE mortgage_backed_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "MBS_UPDATE|999999|MortgageA|RMBS|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "MBS_UPDATE|${id}|MortgageA|RMBS|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0