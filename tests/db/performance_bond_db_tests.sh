#!/usr/bin/env bash
# Performance bond (Wave16) end-to-end DB tests via the COBOL binary.
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
db_reset_performance_bond

# Create a cost center.
create_out="$(run_cobol "PBD_CREATE|PBD-W16-1|ContractorA|CONTRACT|||admin@test.com")"
assert_match "PBD_CREATE ok" "$create_out" "SUCCESS\|PBD_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM performance_bond WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PBD_CREATE|PBD-W16-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PBD_GET ok" "$(run_cobol "PBD_GET|${id}|||||admin@test.com")" "SUCCESS\|PBD_GET\|${id}\|PBD-W16-1"
assert_match "PBD_LIST ok" "$(run_cobol "PBD_LIST|||50|0||admin@test.com")" "PBD-W16-1"

# Allocate.
assert_match "PBD_CALC ok" "$(run_cobol "PBD_CALC|${id}|||||admin@test.com")" "SUCCESS\|PBD_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM performance_bond WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PBD_DELETE ok" "$(run_cobol "PBD_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PBD_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM performance_bond WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PBD_SUMMARY ok" "$(run_cobol "PBD_SUMMARY||||||admin@test.com")" "SUCCESS\|PBD_SUMMARY"
assert_match "PBD_AUDIT ok" "$(run_cobol "PBD_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PBD_AUDIT"
assert_match "PBD_VALIDATE ok" "$(run_cobol "PBD_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PBD_VALID"
assert_match "non-admin refused" "$(run_cobol "PBD_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM performance_bond WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM performance_bond_audit WHERE performance_bond_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "PBD_UPDATE|${id}|ContractorA|CONTRACT|||admin@test.com")"
assert_match "PBD_UPDATE ok" "$upd_out" "SUCCESS\\|PBD_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM performance_bond WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM performance_bond_audit WHERE performance_bond_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "PBD_UPDATE|999999|ContractorA|CONTRACT|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "PBD_UPDATE|${id}|ContractorA|CONTRACT|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0