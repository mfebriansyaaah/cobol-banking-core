#!/usr/bin/env bash
# Total return swap (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_total_return_swap

# Create a cost center.
create_out="$(run_cobol "TRS_CREATE|TRS-W9-1|CounterpartyA|TRS|||admin@test.com")"
assert_match "TRS_CREATE ok" "$create_out" "SUCCESS\|TRS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM total_return_swap WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "TRS_CREATE|TRS-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "TRS_GET ok" "$(run_cobol "TRS_GET|${id}|||||admin@test.com")" "SUCCESS\|TRS_GET\|${id}\|TRS-W9-1"
assert_match "TRS_LIST ok" "$(run_cobol "TRS_LIST|||50|0||admin@test.com")" "TRS-W9-1"

# Allocate.
assert_match "TRS_CALC ok" "$(run_cobol "TRS_CALC|${id}|||||admin@test.com")" "SUCCESS\|TRS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM total_return_swap WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "TRS_DELETE ok" "$(run_cobol "TRS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|TRS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM total_return_swap WHERE id=${id};")" "^MATURED$"

# Summary and audit.
assert_match "TRS_SUMMARY ok" "$(run_cobol "TRS_SUMMARY||||||admin@test.com")" "SUCCESS\|TRS_SUMMARY"
assert_match "TRS_AUDIT ok" "$(run_cobol "TRS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TRS_AUDIT"
assert_match "TRS_VALIDATE ok" "$(run_cobol "TRS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TRS_VALID"
assert_match "non-admin refused" "$(run_cobol "TRS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM total_return_swap WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM total_return_swap_audit WHERE total_return_swap_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "TRS_UPDATE|${id}|CounterpartyA|TRS|||admin@test.com")"
assert_match "TRS_UPDATE ok" "$upd_out" "SUCCESS\\|TRS_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM total_return_swap WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM total_return_swap_audit WHERE total_return_swap_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "TRS_UPDATE|999999|CounterpartyA|TRS|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "TRS_UPDATE|${id}|CounterpartyA|TRS|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0