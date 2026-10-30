#!/usr/bin/env bash
# Merchant onboarding lifecycle (PR-302).
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
db_reset_merchant
db_exec "DELETE FROM customer WHERE customer_ref='CUST-MCHD';"
db_exec "INSERT INTO customer (customer_ref, full_name, customer_type, credit_limit, used_credit, status, kyc_status, created_by) VALUES ('CUST-MCHD','PT MCH','CORPORATE',1000000,0,'ONBOARDED','APPROVED','admin@test.com');"

# CREATE (legacy, OPEN) then link owner.
out="$(run_cobol "MRT_CREATE|MCH-D1|Toko Maju|RETAIL|||admin@test.com")"
assert_match "create ok" "$out" "SUCCESS\|MRT_CREATE\|[0-9]+"
id="$(printf '%s' "$out" | awk -F'|' '{print $3}')"
db_exec "UPDATE merchant SET customer_ref='CUST-MCHD' WHERE id=${id};"

# SUBMIT_KYC: PROSPECT/OPEN -> PENDING_KYC.
assert_match "submit" "$(run_cobol "MRT_SUBMIT_KYC|${id}|||||admin@test.com")" "SUCCESS\|MRT_SUBMIT_KYC"
assert_match "pending kyc" "$(db_query "SELECT status FROM merchant WHERE id=${id};")" "^PENDING_KYC$"
assert_match "submit twice invalid" "$(run_cobol "MRT_SUBMIT_KYC|${id}|||||admin@test.com")" "ERROR\|INVALID_STATE"

# ACTIVATE blocked before APPROVE (no fee profile).
assert_match "activate blocked no fee" "$(run_cobol "MRT_ACTIVATE|${id}|||||admin@test.com")" "ERROR\|INVALID_STATE"

# APPROVE guards.
assert_match "approve bad risk" "$(run_cobol "MRT_APPROVE|${id}|EXTREME|2.5|0|IDR|admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "approve" "$(run_cobol "MRT_APPROVE|${id}|MEDIUM|2.50|1000|IDR|admin@test.com")" "SUCCESS\|MRT_APPROVE"
assert_match "risk stored" "$(db_query "SELECT risk_level FROM merchant WHERE id=${id};")" "^MEDIUM$"
assert_match "fee profile row" "$(db_query "SELECT COUNT(*) FROM merchant_fee_profile WHERE merchant_id=${id};")" "^1$"

# ACTIVATE guards + happy path.
assert_match "activate bad account" "$(run_cobol "MRT_ACTIVATE|${id}|999999||||admin@test.com")" "ERROR\|NOT_FOUND"
assert_match "activate" "$(run_cobol "MRT_ACTIVATE|${id}|||||admin@test.com")" "SUCCESS\|MRT_ACTIVATE"
assert_match "active persisted" "$(db_query "SELECT status FROM merchant WHERE id=${id};")" "^ACTIVE$"

# SET_FEE standalone.
assert_match "set fee" "$(run_cobol "MRT_SET_FEE|${id}|3.00|2000|IDR||admin@test.com")" "SUCCESS\|MRT_SET_FEE"
assert_match "fee rows" "$(db_query "SELECT COUNT(*) FROM merchant_fee_profile WHERE merchant_id=${id};")" "^2$"

# SUSPEND then CLOSE.
assert_match "suspend" "$(run_cobol "MRT_SUSPEND|${id}|||||admin@test.com")" "SUCCESS\|MRT_SUSPEND"
assert_match "suspended persisted" "$(db_query "SELECT status FROM merchant WHERE id=${id};")" "^SUSPENDED$"
assert_match "close" "$(run_cobol "MRT_CLOSE|${id}|Tutup||||admin@test.com")" "SUCCESS\|MRT_CLOSE"
assert_match "closed persisted" "$(db_query "SELECT status FROM merchant WHERE id=${id};")" "^CLOSED$"

# CLOSE blocked with open settlement.
out2="$(run_cobol "MRT_CREATE|MCH-D2|Toko B|RETAIL|||admin@test.com")"
id2="$(printf '%s' "$out2" | awk -F'|' '{print $3}')"
db_exec "UPDATE merchant SET customer_ref='CUST-MCHD', status='ACTIVE' WHERE id=${id2};"
db_exec "INSERT INTO merchant_settlement (settlement_ref, merchant_id, merchant_name, settlement_type, status, created_by) VALUES ('STL-BLK', ${id2}, 'Toko B', 'DAILY', 'OPEN', 'admin@test.com');"
assert_match "close blocked open settlement" "$(run_cobol "MRT_CLOSE|${id2}|Tutup||||admin@test.com")" "ERROR\|INVALID_STATE"
db_exec "DELETE FROM merchant_settlement WHERE settlement_ref='STL-BLK';"
assert_match "close after clear" "$(run_cobol "MRT_CLOSE|${id2}|Tutup||||admin@test.com")" "SUCCESS\|MRT_CLOSE"

assert_match "audit rows" "$(db_query "SELECT COUNT(*) FROM merchant_audit WHERE merchant_id=${id};")" "^[1-9]"
assert_match "non-admin refused" "$(run_cobol "MRT_SUBMIT_KYC|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

# Cleanup.
db_exec "DELETE FROM merchant_settlement_item WHERE settlement_id IN (SELECT id FROM merchant_settlement WHERE merchant_id IN (${id},${id2}));"
db_exec "DELETE FROM merchant_settlement WHERE merchant_id IN (${id},${id2});"
db_exec "DELETE FROM merchant_transaction WHERE merchant_id IN (${id},${id2});"
db_exec "DELETE FROM merchant_fee_profile WHERE merchant_id IN (${id},${id2});"
db_exec "DELETE FROM merchant_audit WHERE merchant_id IN (${id},${id2});"
db_exec "DELETE FROM merchant WHERE id IN (${id},${id2});"
db_exec "DELETE FROM customer WHERE customer_ref='CUST-MCHD';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
