#!/usr/bin/env bash
# Valuation (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_valuation

# Create a cost center.
create_out="$(run_cobol "VAL_CREATE|VAL-W9-1|EntityA|FAIR_VALUE|||admin@test.com")"
assert_match "VAL_CREATE ok" "$create_out" "SUCCESS\|VAL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM valuation WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "VAL_CREATE|VAL-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "VAL_GET ok" "$(run_cobol "VAL_GET|${id}|||||admin@test.com")" "SUCCESS\|VAL_GET\|${id}\|VAL-W9-1"
assert_match "VAL_LIST ok" "$(run_cobol "VAL_LIST|||50|0||admin@test.com")" "VAL-W9-1"

# Allocate.
assert_match "VAL_CALC ok" "$(run_cobol "VAL_CALC|${id}|||||admin@test.com")" "SUCCESS\|VAL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM valuation WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "VAL_DELETE ok" "$(run_cobol "VAL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|VAL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM valuation WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "VAL_SUMMARY ok" "$(run_cobol "VAL_SUMMARY||||||admin@test.com")" "SUCCESS\|VAL_SUMMARY"
assert_match "VAL_AUDIT ok" "$(run_cobol "VAL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|VAL_AUDIT"
assert_match "VAL_VALIDATE ok" "$(run_cobol "VAL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|VAL_VALID"
assert_match "non-admin refused" "$(run_cobol "VAL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM valuation WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM valuation_audit WHERE valuation_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "VAL_UPDATE|${id}|EntityA|FAIR_VALUE|||admin@test.com")"
assert_match "VAL_UPDATE ok" "$upd_out" "SUCCESS\\|VAL_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM valuation WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM valuation_audit WHERE valuation_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "VAL_UPDATE|999999|EntityA|FAIR_VALUE|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "VAL_UPDATE|${id}|EntityA|FAIR_VALUE|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0