#!/usr/bin/env bash
# Transaction (Wave13) end-to-end DB tests via the COBOL binary.
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
db_reset_transaction

# Create a cost center.
create_out="$(run_cobol "TXN_CREATE|TXN-W13-1|AccountA|DEBIT|||admin@test.com")"
assert_match "TXN_CREATE ok" "$create_out" "SUCCESS\|TXN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM transaction WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "TXN_CREATE|TXN-W13-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "TXN_GET ok" "$(run_cobol "TXN_GET|${id}|||||admin@test.com")" "SUCCESS\|TXN_GET\|${id}\|TXN-W13-1"
assert_match "TXN_LIST ok" "$(run_cobol "TXN_LIST|||50|0||admin@test.com")" "TXN-W13-1"

# Allocate.
assert_match "TXN_CALC ok" "$(run_cobol "TXN_CALC|${id}|||||admin@test.com")" "SUCCESS\|TXN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM transaction WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "TXN_DELETE ok" "$(run_cobol "TXN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|TXN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM transaction WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "TXN_SUMMARY ok" "$(run_cobol "TXN_SUMMARY||||||admin@test.com")" "SUCCESS\|TXN_SUMMARY"
assert_match "TXN_AUDIT ok" "$(run_cobol "TXN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TXN_AUDIT"
assert_match "TXN_VALIDATE ok" "$(run_cobol "TXN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TXN_VALID"
assert_match "non-admin refused" "$(run_cobol "TXN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM transaction WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM transaction_audit WHERE transaction_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "TXN_UPDATE|${id}|AccountA|DEBIT|||admin@test.com")"
assert_match "TXN_UPDATE ok" "$upd_out" "SUCCESS\\|TXN_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM transaction WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM transaction_audit WHERE transaction_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "TXN_UPDATE|999999|AccountA|DEBIT|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "TXN_UPDATE|${id}|AccountA|DEBIT|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0