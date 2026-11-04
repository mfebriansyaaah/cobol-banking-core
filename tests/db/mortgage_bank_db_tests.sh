#!/usr/bin/env bash
# Mortgage bank (Wave20) end-to-end DB tests via the COBOL binary.
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
db_reset_mortgage_bank

# Create a cost center.
create_out="$(run_cobol "MTB_CREATE|MTB-W20-1|MortgageA|RESIDENTIAL|||admin@test.com")"
assert_match "MTB_CREATE ok" "$create_out" "SUCCESS\|MTB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM mortgage_bank WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MTB_CREATE|MTB-W20-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MTB_GET ok" "$(run_cobol "MTB_GET|${id}|||||admin@test.com")" "SUCCESS\|MTB_GET\|${id}\|MTB-W20-1"
assert_match "MTB_LIST ok" "$(run_cobol "MTB_LIST|||50|0||admin@test.com")" "MTB-W20-1"

# Allocate.
assert_match "MTB_CALC ok" "$(run_cobol "MTB_CALC|${id}|||||admin@test.com")" "SUCCESS\|MTB_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM mortgage_bank WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MTB_DELETE ok" "$(run_cobol "MTB_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MTB_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM mortgage_bank WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "MTB_SUMMARY ok" "$(run_cobol "MTB_SUMMARY||||||admin@test.com")" "SUCCESS\|MTB_SUMMARY"
assert_match "MTB_AUDIT ok" "$(run_cobol "MTB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MTB_AUDIT"
assert_match "MTB_VALIDATE ok" "$(run_cobol "MTB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MTB_VALID"
assert_match "non-admin refused" "$(run_cobol "MTB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM mortgage_bank WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM mortgage_bank_audit WHERE mortgage_bank_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "MTB_UPDATE|${id}|MortgageA|RESIDENTIAL|||admin@test.com")"
assert_match "MTB_UPDATE ok" "$upd_out" "SUCCESS\\|MTB_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM mortgage_bank WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM mortgage_bank_audit WHERE mortgage_bank_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "MTB_UPDATE|999999|MortgageA|RESIDENTIAL|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "MTB_UPDATE|${id}|MortgageA|RESIDENTIAL|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0