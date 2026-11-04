#!/usr/bin/env bash
# Onboarding (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_onboarding

# Create a cost center.
create_out="$(run_cobol "ONB_CREATE|ONB-W10-1|EmployeeA|STANDARD|||admin@test.com")"
assert_match "ONB_CREATE ok" "$create_out" "SUCCESS\|ONB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM onboarding WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ONB_CREATE|ONB-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ONB_GET ok" "$(run_cobol "ONB_GET|${id}|||||admin@test.com")" "SUCCESS\|ONB_GET\|${id}\|ONB-W10-1"
assert_match "ONB_LIST ok" "$(run_cobol "ONB_LIST|||50|0||admin@test.com")" "ONB-W10-1"

# Allocate.
assert_match "ONB_CALC ok" "$(run_cobol "ONB_CALC|${id}|||||admin@test.com")" "SUCCESS\|ONB_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM onboarding WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ONB_DELETE ok" "$(run_cobol "ONB_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ONB_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM onboarding WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "ONB_SUMMARY ok" "$(run_cobol "ONB_SUMMARY||||||admin@test.com")" "SUCCESS\|ONB_SUMMARY"
assert_match "ONB_AUDIT ok" "$(run_cobol "ONB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ONB_AUDIT"
assert_match "ONB_VALIDATE ok" "$(run_cobol "ONB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ONB_VALID"
assert_match "non-admin refused" "$(run_cobol "ONB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM onboarding WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM onboarding_audit WHERE onboarding_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "ONB_UPDATE|${id}|EmployeeA|STANDARD|||admin@test.com")"
assert_match "ONB_UPDATE ok" "$upd_out" "SUCCESS\\|ONB_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM onboarding WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM onboarding_audit WHERE onboarding_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "ONB_UPDATE|999999|EmployeeA|STANDARD|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "ONB_UPDATE|${id}|EmployeeA|STANDARD|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0