#!/usr/bin/env bash
# Service mesh (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_service_mesh

# Create a cost center.
create_out="$(run_cobol "SVM_CREATE|SVM-W11-1|MeshA|ISTIO|||admin@test.com")"
assert_match "SVM_CREATE ok" "$create_out" "SUCCESS\|SVM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM service_mesh WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SVM_CREATE|SVM-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SVM_GET ok" "$(run_cobol "SVM_GET|${id}|||||admin@test.com")" "SUCCESS\|SVM_GET\|${id}\|SVM-W11-1"
assert_match "SVM_LIST ok" "$(run_cobol "SVM_LIST|||50|0||admin@test.com")" "SVM-W11-1"

# Allocate.
assert_match "SVM_CALC ok" "$(run_cobol "SVM_CALC|${id}|||||admin@test.com")" "SUCCESS\|SVM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM service_mesh WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SVM_DELETE ok" "$(run_cobol "SVM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SVM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM service_mesh WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "SVM_SUMMARY ok" "$(run_cobol "SVM_SUMMARY||||||admin@test.com")" "SUCCESS\|SVM_SUMMARY"
assert_match "SVM_AUDIT ok" "$(run_cobol "SVM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SVM_AUDIT"
assert_match "SVM_VALIDATE ok" "$(run_cobol "SVM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SVM_VALID"
assert_match "non-admin refused" "$(run_cobol "SVM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM service_mesh WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM service_mesh_audit WHERE service_mesh_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "SVM_UPDATE|${id}|MeshA|ISTIO|||admin@test.com")"
assert_match "SVM_UPDATE ok" "$upd_out" "SUCCESS\\|SVM_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM service_mesh WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM service_mesh_audit WHERE service_mesh_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "SVM_UPDATE|999999|MeshA|ISTIO|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "SVM_UPDATE|${id}|MeshA|ISTIO|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0