#!/usr/bin/env bash
# Payment processing (Wave13) end-to-end DB tests via the COBOL binary.
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
db_reset_payment_processing

# Create a cost center.
create_out="$(run_cobol "PAYM_CREATE|PAYM-W13-1|PayerA|WIRE|||admin@test.com")"
assert_match "PAYM_CREATE ok" "$create_out" "SUCCESS\|PAYM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM payment_processing WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PAYM_CREATE|PAYM-W13-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PAYM_GET ok" "$(run_cobol "PAYM_GET|${id}|||||admin@test.com")" "SUCCESS\|PAYM_GET\|${id}\|PAYM-W13-1"
assert_match "PAYM_LIST ok" "$(run_cobol "PAYM_LIST|||50|0||admin@test.com")" "PAYM-W13-1"

# Allocate.
assert_match "PAYM_CALC ok" "$(run_cobol "PAYM_CALC|${id}|||||admin@test.com")" "SUCCESS\|PAYM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM payment_processing WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PAYM_DELETE ok" "$(run_cobol "PAYM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PAYM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM payment_processing WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PAYM_SUMMARY ok" "$(run_cobol "PAYM_SUMMARY||||||admin@test.com")" "SUCCESS\|PAYM_SUMMARY"
assert_match "PAYM_AUDIT ok" "$(run_cobol "PAYM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PAYM_AUDIT"
assert_match "PAYM_VALIDATE ok" "$(run_cobol "PAYM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PAYM_VALID"
assert_match "non-admin refused" "$(run_cobol "PAYM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"




# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM payment_processing WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM payment_processing_audit WHERE payment_processing_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "PAYM_UPDATE|${id}|PayerA|WIRE|||admin@test.com")"
assert_match "PAYM_UPDATE ok" "$upd_out" "SUCCESS\\|PAYM_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM payment_processing WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM payment_processing_audit WHERE payment_processing_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "PAYM_UPDATE|999999|PayerA|WIRE|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "PAYM_UPDATE|${id}|PayerA|WIRE|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0