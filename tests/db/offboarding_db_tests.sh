#!/usr/bin/env bash
# Offboarding (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_offboarding

# Create a cost center.
create_out="$(run_cobol "OFB_CREATE|OFB-W10-1|EmployeeA|RESIGNATION|||admin@test.com")"
assert_match "OFB_CREATE ok" "$create_out" "SUCCESS\|OFB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM offboarding WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "OFB_CREATE|OFB-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "OFB_GET ok" "$(run_cobol "OFB_GET|${id}|||||admin@test.com")" "SUCCESS\|OFB_GET\|${id}\|OFB-W10-1"
assert_match "OFB_LIST ok" "$(run_cobol "OFB_LIST|||50|0||admin@test.com")" "OFB-W10-1"

# Allocate.
assert_match "OFB_CALC ok" "$(run_cobol "OFB_CALC|${id}|||||admin@test.com")" "SUCCESS\|OFB_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM offboarding WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "OFB_DELETE ok" "$(run_cobol "OFB_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|OFB_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM offboarding WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "OFB_SUMMARY ok" "$(run_cobol "OFB_SUMMARY||||||admin@test.com")" "SUCCESS\|OFB_SUMMARY"
assert_match "OFB_AUDIT ok" "$(run_cobol "OFB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|OFB_AUDIT"
assert_match "OFB_VALIDATE ok" "$(run_cobol "OFB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|OFB_VALID"
assert_match "non-admin refused" "$(run_cobol "OFB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM offboarding WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM offboarding_audit WHERE offboarding_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "OFB_UPDATE|${id}|EmployeeA|RESIGNATION|||admin@test.com")"
assert_match "OFB_UPDATE ok" "$upd_out" "SUCCESS\\|OFB_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM offboarding WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM offboarding_audit WHERE offboarding_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "OFB_UPDATE|999999|EmployeeA|RESIGNATION|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "OFB_UPDATE|${id}|EmployeeA|RESIGNATION|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0