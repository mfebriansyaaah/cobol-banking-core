#!/usr/bin/env bash
# Merchant settlement + fee + payout (PR-303).
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
db_exec "DELETE FROM customer WHERE customer_ref='CUST-MCHS';"
db_exec "INSERT INTO customer (customer_ref, full_name, customer_type, credit_limit, used_credit, status, kyc_status, created_by) VALUES ('CUST-MCHS','PT S','CORPORATE',1000000,0,'ONBOARDED','APPROVED','admin@test.com');"

# Settlement period must contain TODAY: txns are captured with captured_at=NOW()
# while the batch filters DATE(captured_at) BETWEEN period_start..period_end.
# A hardcoded month breaks every month-boundary (e.g. November txns in an
# October window select 0 rows and CALC fails with INVALID_STATE).
PERIOD_START="$(date +%Y-%m-01)"
PERIOD_END="$(date -d "$PERIOD_START +1 month -1 day" +%F)"

# Onboard an ACTIVE merchant with fee profile.
out="$(run_cobol "MRT_CREATE|MCH-S1|Toko S|RETAIL|||admin@test.com")"
mid="$(printf '%s' "$out" | awk -F'|' '{print $3}')"
db_exec "UPDATE merchant SET customer_ref='CUST-MCHS' WHERE id=${mid};"
run_cobol "MRT_SUBMIT_KYC|${mid}|||||admin@test.com" >/dev/null
run_cobol "MRT_APPROVE|${mid}|MEDIUM|2.50|1000|IDR|admin@test.com" >/dev/null
acc="$(db_query "SELECT account_id FROM accounts LIMIT 1;")"
run_cobol "MRT_ACTIVATE|${mid}|${acc}||||admin@test.com" >/dev/null
assert_match "merchant active" "$(db_query "SELECT status FROM merchant WHERE id=${mid};")" "^ACTIVE$"

# TXN ingest with fee (100000*2.5%+1000=3500, 200000*2.5%+1000=6000).
assert_match "txn1" "$(run_cobol "MCS_TXN|${mid}|TXN-MS1|100000|IDR|PMC-1|admin@test.com")" "SUCCESS\|MCS_TXN"
assert_match "txn2" "$(run_cobol "MCS_TXN|${mid}|TXN-MS2|200000|IDR||admin@test.com")" "SUCCESS\|MCS_TXN"
assert_match "txn fee1" "$(db_query "SELECT fee_amount FROM merchant_transaction WHERE txn_ref='TXN-MS1';")" "^3500"
assert_match "txn net2" "$(db_query "SELECT net_amount FROM merchant_transaction WHERE txn_ref='TXN-MS2';")" "^194000"
assert_match "duplicate txn" "$(run_cobol "MCS_TXN|${mid}|TXN-MS1|100000|IDR||admin@test.com")" "ERROR\|DUPLICATE"
assert_match "txn suspended blocked" "$(run_cobol "MRT_SUSPEND|${mid}|||||admin@test.com")" "SUCCESS\|MRT_SUSPEND"
assert_match "txn while suspended" "$(run_cobol "MCS_TXN|${mid}|TXN-MS3|50000|IDR||admin@test.com")" "ERROR\|INVALID_STATE"
db_exec "UPDATE merchant SET status='ACTIVE', version=version+1 WHERE id=${mid};"

# Settlement batch OPEN -> CALC -> POST -> SETTLE.
op="$(run_cobol "MCS_OPEN|${mid}|STL-MS1|${PERIOD_START}|${PERIOD_END}|IDR|admin@test.com")"
assert_match "open" "$op" "SUCCESS\|MCS_OPEN\|[0-9]+"
sid="$(printf '%s' "$op" | awk -F'|' '{print $3}')"
assert_match "open persisted" "$(db_query "SELECT status FROM merchant_settlement WHERE id=${sid};")" "^OPEN$"
assert_match "duplicate ref" "$(run_cobol "MCS_OPEN|${mid}|STL-MS1|${PERIOD_START}|${PERIOD_END}|IDR|admin@test.com")" "ERROR\|DUPLICATE"
assert_match "calc" "$(run_cobol "MCS_CALC|${sid}|||||admin@test.com")" "SUCCESS\|MCS_CALC\|2"
assert_match "gross" "$(db_query "SELECT gross_amount FROM merchant_settlement WHERE id=${sid};")" "^300000"
assert_match "fee" "$(db_query "SELECT fee_amount FROM merchant_settlement WHERE id=${sid};")" "^9500"
assert_match "net" "$(db_query "SELECT net_amount FROM merchant_settlement WHERE id=${sid};")" "^290500"
assert_match "items" "$(db_query "SELECT COUNT(*) FROM merchant_settlement_item WHERE settlement_id=${sid};")" "^2$"
assert_match "calc twice blocked" "$(run_cobol "MCS_CALC|${sid}|||||admin@test.com")" "ERROR\|INVALID_STATE"
assert_match "post" "$(run_cobol "MCS_POST|${sid}|PMC-P1|777|||admin@test.com")" "SUCCESS\|MCS_POST"
assert_match "scheduled" "$(db_query "SELECT status FROM merchant_settlement WHERE id=${sid};")" "^SCHEDULED$"
assert_match "settle" "$(run_cobol "MCS_SETTLE|${sid}|||||admin@test.com")" "SUCCESS\|MCS_SETTLE"
assert_match "paid" "$(db_query "SELECT status FROM merchant_settlement WHERE id=${sid};")" "^PAID$"
assert_match "paid amount" "$(db_query "SELECT paid_amount FROM merchant_settlement WHERE id=${sid};")" "^290500"
assert_match "txn settled" "$(db_query "SELECT COUNT(*) FROM merchant_transaction WHERE settlement_id=${sid} AND status='SETTLED';")" "^2$"
assert_match "volume" "$(db_query "SELECT settled_volume FROM merchant WHERE id=${mid};")" "^290500"

# CANCEL path: new batch, calc, cancel releases txns.
op2="$(run_cobol "MCS_OPEN|${mid}|STL-MS2|${PERIOD_START}|${PERIOD_END}|IDR|admin@test.com")"
sid2="$(printf '%s' "$op2" | awk -F'|' '{print $3}')"
run_cobol "MCS_TXN|${mid}|TXN-MS3|50000|IDR||admin@test.com" >/dev/null
run_cobol "MCS_CALC|${sid2}|||||admin@test.com" >/dev/null
assert_match "cancel" "$(run_cobol "MCS_CANCEL|${sid2}|Batal||||admin@test.com")" "SUCCESS\|MCS_CANCEL"
assert_match "cancelled" "$(db_query "SELECT status FROM merchant_settlement WHERE id=${sid2};")" "^CANCELLED$"
assert_match "txn released" "$(db_query "SELECT COUNT(*) FROM merchant_transaction WHERE txn_ref='TXN-MS3' AND settlement_id IS NULL;")" "^1$"

assert_match "audit rows" "$(db_query "SELECT COUNT(*) FROM merchant_settlement_audit WHERE merchant_settlement_id=${sid};")" "^[1-9]"
assert_match "non-admin refused" "$(run_cobol "MCS_TXN|${mid}|TXN-X|100|IDR||sender@test.com")" "ERROR\|FORBIDDEN"

# Cleanup.
db_exec "DELETE FROM merchant_settlement_item WHERE settlement_id IN (${sid},${sid2});"
db_exec "DELETE FROM merchant_settlement WHERE id IN (${sid},${sid2});"
db_exec "DELETE FROM merchant_transaction WHERE merchant_id=${mid};"
db_exec "DELETE FROM merchant_fee_profile WHERE merchant_id=${mid};"
db_exec "DELETE FROM merchant_audit WHERE merchant_id=${mid};"
db_exec "DELETE FROM merchant WHERE id=${mid};"
db_exec "DELETE FROM customer WHERE customer_ref='CUST-MCHS';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
