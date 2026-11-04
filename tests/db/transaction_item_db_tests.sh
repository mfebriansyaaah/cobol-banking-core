#!/usr/bin/env bash
# Transaction item (Wave15) end-to-end DB tests via the COBOL binary.
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
db_reset_transaction_item

# Create a cost center.
create_out="$(run_cobol "TXNS_CREATE|TXNS-W15-1|AccountA|DEBIT|||admin@test.com")"
assert_match "TXNS_CREATE ok" "$create_out" "SUCCESS\|TXNS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM transaction_item WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "TXNS_CREATE|TXNS-W15-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "TXNS_GET ok" "$(run_cobol "TXNS_GET|${id}|||||admin@test.com")" "SUCCESS\|TXNS_GET\|${id}\|TXNS-W15-1"
assert_match "TXNS_LIST ok" "$(run_cobol "TXNS_LIST|||50|0||admin@test.com")" "TXNS-W15-1"

# Allocate.
assert_match "TXNS_CALC ok" "$(run_cobol "TXNS_CALC|${id}|||||admin@test.com")" "SUCCESS\|TXNS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM transaction_item WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "TXNS_DELETE ok" "$(run_cobol "TXNS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|TXNS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM transaction_item WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "TXNS_SUMMARY ok" "$(run_cobol "TXNS_SUMMARY||||||admin@test.com")" "SUCCESS\|TXNS_SUMMARY"
assert_match "TXNS_AUDIT ok" "$(run_cobol "TXNS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TXNS_AUDIT"
assert_match "TXNS_VALIDATE ok" "$(run_cobol "TXNS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TXNS_VALID"
assert_match "non-admin refused" "$(run_cobol "TXNS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM transaction_item WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM transaction_item_audit WHERE transaction_item_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "TXNS_UPDATE|${id}|AccountA|DEBIT|||admin@test.com")"
assert_match "TXNS_UPDATE ok" "$upd_out" "SUCCESS\\|TXNS_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM transaction_item WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM transaction_item_audit WHERE transaction_item_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "TXNS_UPDATE|999999|AccountA|DEBIT|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "TXNS_UPDATE|${id}|AccountA|DEBIT|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0