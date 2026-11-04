#!/usr/bin/env bash
# Outsourcing contract (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_outsourcing_contract

# Create a cost center.
create_out="$(run_cobol "OSC_CREATE|OSC-W7-1|ContractA|SERVICE|||admin@test.com")"
assert_match "OSC_CREATE ok" "$create_out" "SUCCESS\|OSC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM outsourcing_contract WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "OSC_CREATE|OSC-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "OSC_GET ok" "$(run_cobol "OSC_GET|${id}|||||admin@test.com")" "SUCCESS\|OSC_GET\|${id}\|OSC-W7-1"
assert_match "OSC_LIST ok" "$(run_cobol "OSC_LIST|||50|0||admin@test.com")" "OSC-W7-1"

# Allocate.
assert_match "OSC_CALC ok" "$(run_cobol "OSC_CALC|${id}|||||admin@test.com")" "SUCCESS\|OSC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM outsourcing_contract WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "OSC_DELETE ok" "$(run_cobol "OSC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|OSC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM outsourcing_contract WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "OSC_SUMMARY ok" "$(run_cobol "OSC_SUMMARY||||||admin@test.com")" "SUCCESS\|OSC_SUMMARY"
assert_match "OSC_AUDIT ok" "$(run_cobol "OSC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|OSC_AUDIT"
assert_match "OSC_VALIDATE ok" "$(run_cobol "OSC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|OSC_VALID"
assert_match "non-admin refused" "$(run_cobol "OSC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM outsourcing_contract WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM outsourcing_contract_audit WHERE outsourcing_contract_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "OSC_UPDATE|${id}|ContractA|SERVICE|||admin@test.com")"
assert_match "OSC_UPDATE ok" "$upd_out" "SUCCESS\\|OSC_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM outsourcing_contract WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM outsourcing_contract_audit WHERE outsourcing_contract_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "OSC_UPDATE|999999|ContractA|SERVICE|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "OSC_UPDATE|${id}|ContractA|SERVICE|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0