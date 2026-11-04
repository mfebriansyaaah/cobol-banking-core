#!/usr/bin/env bash
# Professional indemnity (Wave18) end-to-end DB tests via the COBOL binary.
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
db_reset_professional_indemnity

# Create a cost center.
create_out="$(run_cobol "PIN_CREATE|PIN-W18-1|ProfessionalA|MEDICAL|||admin@test.com")"
assert_match "PIN_CREATE ok" "$create_out" "SUCCESS\|PIN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM professional_indemnity WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PIN_CREATE|PIN-W18-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PIN_GET ok" "$(run_cobol "PIN_GET|${id}|||||admin@test.com")" "SUCCESS\|PIN_GET\|${id}\|PIN-W18-1"
assert_match "PIN_LIST ok" "$(run_cobol "PIN_LIST|||50|0||admin@test.com")" "PIN-W18-1"

# Allocate.
assert_match "PIN_CALC ok" "$(run_cobol "PIN_CALC|${id}|||||admin@test.com")" "SUCCESS\|PIN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM professional_indemnity WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PIN_DELETE ok" "$(run_cobol "PIN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PIN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM professional_indemnity WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PIN_SUMMARY ok" "$(run_cobol "PIN_SUMMARY||||||admin@test.com")" "SUCCESS\|PIN_SUMMARY"
assert_match "PIN_AUDIT ok" "$(run_cobol "PIN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PIN_AUDIT"
assert_match "PIN_VALIDATE ok" "$(run_cobol "PIN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PIN_VALID"
assert_match "non-admin refused" "$(run_cobol "PIN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM professional_indemnity WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM professional_indemnity_audit WHERE professional_indemnity_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "PIN_UPDATE|${id}|ProfessionalA|MEDICAL|||admin@test.com")"
assert_match "PIN_UPDATE ok" "$upd_out" "SUCCESS\\|PIN_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM professional_indemnity WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM professional_indemnity_audit WHERE professional_indemnity_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "PIN_UPDATE|999999|ProfessionalA|MEDICAL|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "PIN_UPDATE|${id}|ProfessionalA|MEDICAL|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0