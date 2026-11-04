#!/usr/bin/env bash
# Transaction limit (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_transaction_limit

# Create a cost center.
create_out="$(run_cobol "TXL_CREATE|TXL-W8-1|AccountA|DAILY|||admin@test.com")"
assert_match "TXL_CREATE ok" "$create_out" "SUCCESS\|TXL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM transaction_limit WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "TXL_CREATE|TXL-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "TXL_GET ok" "$(run_cobol "TXL_GET|${id}|||||admin@test.com")" "SUCCESS\|TXL_GET\|${id}\|TXL-W8-1"
assert_match "TXL_LIST ok" "$(run_cobol "TXL_LIST|||50|0||admin@test.com")" "TXL-W8-1"

# Allocate.
assert_match "TXL_CALC ok" "$(run_cobol "TXL_CALC|${id}|||||admin@test.com")" "SUCCESS\|TXL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM transaction_limit WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "TXL_DELETE ok" "$(run_cobol "TXL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|TXL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM transaction_limit WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "TXL_SUMMARY ok" "$(run_cobol "TXL_SUMMARY||||||admin@test.com")" "SUCCESS\|TXL_SUMMARY"
assert_match "TXL_AUDIT ok" "$(run_cobol "TXL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TXL_AUDIT"
assert_match "TXL_VALIDATE ok" "$(run_cobol "TXL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TXL_VALID"
assert_match "non-admin refused" "$(run_cobol "TXL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM transaction_limit WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM transaction_limit_audit WHERE transaction_limit_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "TXL_UPDATE|${id}|AccountA|DAILY|||admin@test.com")"
assert_match "TXL_UPDATE ok" "$upd_out" "SUCCESS\\|TXL_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM transaction_limit WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM transaction_limit_audit WHERE transaction_limit_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "TXL_UPDATE|999999|AccountA|DAILY|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "TXL_UPDATE|${id}|AccountA|DAILY|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0