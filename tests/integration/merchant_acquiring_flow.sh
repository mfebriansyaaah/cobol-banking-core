#!/usr/bin/env bash
# Integration: merchant onboarding -> txn -> settlement -> payout + GL.
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
db_reset_merchant_settlement
db_exec "DELETE FROM customer WHERE customer_ref='CUST-MCHINT';"
db_exec "INSERT INTO customer (customer_ref, full_name, customer_type, credit_limit, used_credit, status, kyc_status, created_by) VALUES ('CUST-MCHINT','PT Int','CORPORATE',1000000,0,'ONBOARDED','APPROVED','admin@test.com');"
ADMIN="mchint@test.com"
db_exec "INSERT INTO users (email, password_hash, full_name, dob, status, role) VALUES ('$ADMIN', CONCAT('SHA256_',SHA2('secret123',256)), 'Mch Int', '1990-01-01', 'VERIFIED', 'SUPER_ADMIN') ON DUPLICATE KEY UPDATE role='SUPER_ADMIN', status='VERIFIED';"

echo "=== Merchant acquiring integration ==="

OUT=$(run_cobol "MRT_CREATE|MCH-INT-1|Toko Int|RETAIL|||$ADMIN")
assert_match "create" "$OUT" "SUCCESS\|MRT_CREATE"
MID=$(printf '%s' "$OUT" | awk -F'|' '{print $3}')
db_exec "UPDATE merchant SET customer_ref='CUST-MCHINT' WHERE id=${MID};"

assert_match "submit kyc" "$(run_cobol "MRT_SUBMIT_KYC|${MID}|||||$ADMIN")" "SUCCESS\|MRT_SUBMIT_KYC"
assert_match "approve" "$(run_cobol "MRT_APPROVE|${MID}|MEDIUM|2.00|500|IDR|$ADMIN")" "SUCCESS\|MRT_APPROVE"
ACC=$(db_query "SELECT account_id FROM accounts LIMIT 1;")
assert_match "activate" "$(run_cobol "MRT_ACTIVATE|${MID}|${ACC}||||$ADMIN")" "SUCCESS\|MRT_ACTIVATE"

assert_match "txn1" "$(run_cobol "MCS_TXN|${MID}|TXN-INT-1|100000|IDR|PMC-I1|$ADMIN")" "SUCCESS\|MCS_TXN"
assert_match "txn2" "$(run_cobol "MCS_TXN|${MID}|TXN-INT-2|200000|IDR||$ADMIN")" "SUCCESS\|MCS_TXN"

OP=$(run_cobol "MCS_OPEN|${MID}|STL-INT-1|2026-10-01|2026-10-31|IDR|$ADMIN")
assert_match "open" "$OP" "SUCCESS\|MCS_OPEN"
SID=$(printf '%s' "$OP" | awk -F'|' '{print $3}')
assert_match "calc" "$(run_cobol "MCS_CALC|${SID}|||||$ADMIN")" "SUCCESS\|MCS_CALC"

# GL: net = (100000-2500) + (200000-4500) = 293000.
# debit settlement clearing (5000 expense), credit merchant payable (1100).
GL_OUT=$(run_cobol "GL_JOURNAL_POST|2026-10-30|Merchant STL-INT-1|5000|1100|IDR:293000|$ADMIN")
assert_match "gl posted" "$GL_OUT" "SUCCESS\|GL_POSTED"
GJID=$(db_query "SELECT id FROM gl_journal ORDER BY id DESC LIMIT 1;")
assert_match "gl balanced" "$(db_query "SELECT IF(SUM(debit_amount)=SUM(credit_amount) AND SUM(debit_amount)>0,'BALANCED','UNBALANCED') FROM gl_journal_line WHERE journal_id=${GJID};")" "^BALANCED$"

assert_match "post" "$(run_cobol "MCS_POST|${SID}|PMC-PINT|${GJID}|||$ADMIN")" "SUCCESS\|MCS_POST"
assert_match "settle" "$(run_cobol "MCS_SETTLE|${SID}|||||$ADMIN")" "SUCCESS\|MCS_SETTLE"
assert_match "paid" "$(db_query "SELECT status FROM merchant_settlement WHERE id=${SID};")" "^PAID$"
assert_match "gl linked" "$(db_query "SELECT gl_journal_id FROM merchant_settlement WHERE id=${SID};")" "^${GJID}$"
assert_match "volume" "$(db_query "SELECT settled_volume FROM merchant WHERE id=${MID};")" "^293000"

# Cleanup.
db_exec "DELETE FROM merchant_settlement_item WHERE settlement_id=${SID};"
db_exec "DELETE FROM merchant_settlement WHERE id=${SID};"
db_exec "DELETE FROM merchant_transaction WHERE merchant_id=${MID};"
db_exec "DELETE FROM merchant_fee_profile WHERE merchant_id=${MID};"
db_exec "DELETE FROM merchant_audit WHERE merchant_id=${MID};"
db_exec "DELETE FROM merchant WHERE id=${MID};"
db_exec "DELETE FROM customer WHERE customer_ref='CUST-MCHINT';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
