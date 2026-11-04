#!/usr/bin/env bash
# Professional risk (Wave18) end-to-end DB tests via the COBOL binary.
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
db_reset_professional_risk

# Create a cost center.
create_out="$(run_cobol "PRK_CREATE|PRK-W18-1|ProfessionalA|MALPRACTICE|||admin@test.com")"
assert_match "PRK_CREATE ok" "$create_out" "SUCCESS\|PRK_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM professional_risk WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PRK_CREATE|PRK-W18-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PRK_GET ok" "$(run_cobol "PRK_GET|${id}|||||admin@test.com")" "SUCCESS\|PRK_GET\|${id}\|PRK-W18-1"
assert_match "PRK_LIST ok" "$(run_cobol "PRK_LIST|||50|0||admin@test.com")" "PRK-W18-1"

# Allocate.
assert_match "PRK_CALC ok" "$(run_cobol "PRK_CALC|${id}|||||admin@test.com")" "SUCCESS\|PRK_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM professional_risk WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PRK_DELETE ok" "$(run_cobol "PRK_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PRK_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM professional_risk WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PRK_SUMMARY ok" "$(run_cobol "PRK_SUMMARY||||||admin@test.com")" "SUCCESS\|PRK_SUMMARY"
assert_match "PRK_AUDIT ok" "$(run_cobol "PRK_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PRK_AUDIT"
assert_match "PRK_VALIDATE ok" "$(run_cobol "PRK_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PRK_VALID"
assert_match "non-admin refused" "$(run_cobol "PRK_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM professional_risk WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM professional_risk_audit WHERE professional_risk_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "PRK_UPDATE|${id}|ProfessionalA|MALPRACTICE|||admin@test.com")"
assert_match "PRK_UPDATE ok" "$upd_out" "SUCCESS\\|PRK_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM professional_risk WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM professional_risk_audit WHERE professional_risk_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "PRK_UPDATE|999999|ProfessionalA|MALPRACTICE|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "PRK_UPDATE|${id}|ProfessionalA|MALPRACTICE|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0