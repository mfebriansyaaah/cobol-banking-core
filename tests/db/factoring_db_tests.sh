#!/usr/bin/env bash
# Factoring (Wave16) end-to-end DB tests via the COBOL binary.
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
db_reset_factoring

# Create a cost center.
create_out="$(run_cobol "FCT_CREATE|FCT-W16-1|ClientA|RECOURSE|||admin@test.com")"
assert_match "FCT_CREATE ok" "$create_out" "SUCCESS\|FCT_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM factoring WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "FCT_CREATE|FCT-W16-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "FCT_GET ok" "$(run_cobol "FCT_GET|${id}|||||admin@test.com")" "SUCCESS\|FCT_GET\|${id}\|FCT-W16-1"
assert_match "FCT_LIST ok" "$(run_cobol "FCT_LIST|||50|0||admin@test.com")" "FCT-W16-1"

# Allocate.
assert_match "FCT_CALC ok" "$(run_cobol "FCT_CALC|${id}|||||admin@test.com")" "SUCCESS\|FCT_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM factoring WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "FCT_DELETE ok" "$(run_cobol "FCT_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|FCT_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM factoring WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "FCT_SUMMARY ok" "$(run_cobol "FCT_SUMMARY||||||admin@test.com")" "SUCCESS\|FCT_SUMMARY"
assert_match "FCT_AUDIT ok" "$(run_cobol "FCT_AUDIT|50|0||||admin@test.com")" "SUCCESS\|FCT_AUDIT"
assert_match "FCT_VALIDATE ok" "$(run_cobol "FCT_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|FCT_VALID"
assert_match "non-admin refused" "$(run_cobol "FCT_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM factoring WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM factoring_audit WHERE factoring_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "FCT_UPDATE|${id}|ClientA|RECOURSE|||admin@test.com")"
assert_match "FCT_UPDATE ok" "$upd_out" "SUCCESS\\|FCT_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM factoring WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM factoring_audit WHERE factoring_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "FCT_UPDATE|999999|ClientA|RECOURSE|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "FCT_UPDATE|${id}|ClientA|RECOURSE|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0