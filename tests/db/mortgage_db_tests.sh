#!/usr/bin/env bash
# Mortgage (Wave16) end-to-end DB tests via the COBOL binary.
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
db_reset_mortgage

# Create a cost center.
create_out="$(run_cobol "MTG_CREATE|MTG-W16-1|BorrowerA|FIXED|||admin@test.com")"
assert_match "MTG_CREATE ok" "$create_out" "SUCCESS\|MTG_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM mortgage WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MTG_CREATE|MTG-W16-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MTG_GET ok" "$(run_cobol "MTG_GET|${id}|||||admin@test.com")" "SUCCESS\|MTG_GET\|${id}\|MTG-W16-1"
assert_match "MTG_LIST ok" "$(run_cobol "MTG_LIST|||50|0||admin@test.com")" "MTG-W16-1"

# Allocate.
assert_match "MTG_CALC ok" "$(run_cobol "MTG_CALC|${id}|||||admin@test.com")" "SUCCESS\|MTG_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM mortgage WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MTG_DELETE ok" "$(run_cobol "MTG_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MTG_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM mortgage WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "MTG_SUMMARY ok" "$(run_cobol "MTG_SUMMARY||||||admin@test.com")" "SUCCESS\|MTG_SUMMARY"
assert_match "MTG_AUDIT ok" "$(run_cobol "MTG_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MTG_AUDIT"
assert_match "MTG_VALIDATE ok" "$(run_cobol "MTG_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MTG_VALID"
assert_match "non-admin refused" "$(run_cobol "MTG_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"




# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM mortgage WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM mortgage_audit WHERE mortgage_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "MTG_UPDATE|${id}|BorrowerA|FIXED|||admin@test.com")"
assert_match "MTG_UPDATE ok" "$upd_out" "SUCCESS\\|MTG_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM mortgage WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM mortgage_audit WHERE mortgage_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "MTG_UPDATE|999999|BorrowerA|FIXED|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "MTG_UPDATE|${id}|BorrowerA|FIXED|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0