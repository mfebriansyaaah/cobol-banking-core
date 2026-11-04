#!/usr/bin/env bash
# QR payment (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_qr_payment

# Create a cost center.
create_out="$(run_cobol "QRP_CREATE|QRP-W8-1|MerchantA|DYNAMIC|||admin@test.com")"
assert_match "QRP_CREATE ok" "$create_out" "SUCCESS\|QRP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM qr_payment WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "QRP_CREATE|QRP-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "QRP_GET ok" "$(run_cobol "QRP_GET|${id}|||||admin@test.com")" "SUCCESS\|QRP_GET\|${id}\|QRP-W8-1"
assert_match "QRP_LIST ok" "$(run_cobol "QRP_LIST|||50|0||admin@test.com")" "QRP-W8-1"

# Allocate.
assert_match "QRP_CALC ok" "$(run_cobol "QRP_CALC|${id}|||||admin@test.com")" "SUCCESS\|QRP_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM qr_payment WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "QRP_DELETE ok" "$(run_cobol "QRP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|QRP_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM qr_payment WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "QRP_SUMMARY ok" "$(run_cobol "QRP_SUMMARY||||||admin@test.com")" "SUCCESS\|QRP_SUMMARY"
assert_match "QRP_AUDIT ok" "$(run_cobol "QRP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|QRP_AUDIT"
assert_match "QRP_VALIDATE ok" "$(run_cobol "QRP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|QRP_VALID"
assert_match "non-admin refused" "$(run_cobol "QRP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"




# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM qr_payment WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM qr_payment_audit WHERE qr_payment_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "QRP_UPDATE|${id}|MerchantA|DYNAMIC|||admin@test.com")"
assert_match "QRP_UPDATE ok" "$upd_out" "SUCCESS\\|QRP_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM qr_payment WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM qr_payment_audit WHERE qr_payment_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "QRP_UPDATE|999999|MerchantA|DYNAMIC|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "QRP_UPDATE|${id}|MerchantA|DYNAMIC|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0