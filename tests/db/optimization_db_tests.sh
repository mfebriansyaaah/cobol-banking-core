#!/usr/bin/env bash
# Optimization (Wave14) end-to-end DB tests via the COBOL binary.
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
db_reset_optimization

# Create a cost center.
create_out="$(run_cobol "OPTM_CREATE|OPTM-W14-1|OptA|LINEAR|||admin@test.com")"
assert_match "OPTM_CREATE ok" "$create_out" "SUCCESS\|OPTM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM optimization WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "OPTM_CREATE|OPTM-W14-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "OPTM_GET ok" "$(run_cobol "OPTM_GET|${id}|||||admin@test.com")" "SUCCESS\|OPTM_GET\|${id}\|OPTM-W14-1"
assert_match "OPTM_LIST ok" "$(run_cobol "OPTM_LIST|||50|0||admin@test.com")" "OPTM-W14-1"

# Allocate.
assert_match "OPTM_CALC ok" "$(run_cobol "OPTM_CALC|${id}|||||admin@test.com")" "SUCCESS\|OPTM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM optimization WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "OPTM_DELETE ok" "$(run_cobol "OPTM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|OPTM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM optimization WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "OPTM_SUMMARY ok" "$(run_cobol "OPTM_SUMMARY||||||admin@test.com")" "SUCCESS\|OPTM_SUMMARY"
assert_match "OPTM_AUDIT ok" "$(run_cobol "OPTM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|OPTM_AUDIT"
assert_match "OPTM_VALIDATE ok" "$(run_cobol "OPTM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|OPTM_VALID"
assert_match "non-admin refused" "$(run_cobol "OPTM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM optimization WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM optimization_audit WHERE optimization_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "OPTM_UPDATE|${id}|OptA|LINEAR|||admin@test.com")"
assert_match "OPTM_UPDATE ok" "$upd_out" "SUCCESS\\|OPTM_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM optimization WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM optimization_audit WHERE optimization_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "OPTM_UPDATE|999999|OptA|LINEAR|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "OPTM_UPDATE|${id}|OptA|LINEAR|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0