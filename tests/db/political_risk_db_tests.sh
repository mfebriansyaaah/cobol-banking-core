#!/usr/bin/env bash
# Political risk (Wave18) end-to-end DB tests via the COBOL binary.
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
db_reset_political_risk

# Create a cost center.
create_out="$(run_cobol "POL_CREATE|POL-W18-1|InvestorA|EXPROPRIATION|||admin@test.com")"
assert_match "POL_CREATE ok" "$create_out" "SUCCESS\|POL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM political_risk WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "POL_CREATE|POL-W18-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "POL_GET ok" "$(run_cobol "POL_GET|${id}|||||admin@test.com")" "SUCCESS\|POL_GET\|${id}\|POL-W18-1"
assert_match "POL_LIST ok" "$(run_cobol "POL_LIST|||50|0||admin@test.com")" "POL-W18-1"

# Allocate.
assert_match "POL_CALC ok" "$(run_cobol "POL_CALC|${id}|||||admin@test.com")" "SUCCESS\|POL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM political_risk WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "POL_DELETE ok" "$(run_cobol "POL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|POL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM political_risk WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "POL_SUMMARY ok" "$(run_cobol "POL_SUMMARY||||||admin@test.com")" "SUCCESS\|POL_SUMMARY"
assert_match "POL_AUDIT ok" "$(run_cobol "POL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|POL_AUDIT"
assert_match "POL_VALIDATE ok" "$(run_cobol "POL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|POL_VALID"
assert_match "non-admin refused" "$(run_cobol "POL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM political_risk WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM political_risk_audit WHERE political_risk_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "POL_UPDATE|${id}|InvestorA|EXPROPRIATION|||admin@test.com")"
assert_match "POL_UPDATE ok" "$upd_out" "SUCCESS\\|POL_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM political_risk WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM political_risk_audit WHERE political_risk_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "POL_UPDATE|999999|InvestorA|EXPROPRIATION|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "POL_UPDATE|${id}|InvestorA|EXPROPRIATION|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0