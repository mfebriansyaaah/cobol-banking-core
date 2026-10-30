#!/usr/bin/env bash
# Merchant Acquiring schema/constraint tests (PR-301).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
require_db

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

# Merchant with owner + risk + prospect status.
db_exec "DELETE FROM merchant WHERE merchant_ref='MCH-S1';"
db_exec "INSERT INTO merchant (merchant_ref, customer_ref, merchant_name, merchant_type, risk_level, status, created_by) VALUES ('MCH-S1','CUST-1','Toko Maju','RETAIL','MEDIUM','PROSPECT','admin@test.com');"
MID="$(db_query "SELECT id FROM merchant WHERE merchant_ref='MCH-S1';")"
assert_match "merchant inserted" "$MID" "^[0-9]+$"
assert_match "status prospect" "$(db_query "SELECT status FROM merchant WHERE id=${MID};")" "^PROSPECT$"

# Fee profile with effective window.
db_exec "INSERT INTO merchant_fee_profile (merchant_id, mdr_pct, fixed_fee, currency, effective_from, created_by) VALUES (${MID}, 2.50, 1000, 'IDR', CURRENT_DATE, 'admin@test.com');"
assert_match "fee profile row" "$(db_query "SELECT COUNT(*) FROM merchant_fee_profile WHERE merchant_id=${MID};")" "^1$"
db_exec "INSERT INTO merchant_fee_profile (merchant_id, mdr_pct, fixed_fee, currency, effective_from, created_by) VALUES (${MID}, 200, 0, 'IDR', CURRENT_DATE, 'admin@test.com');" 2>/dev/null
assert_match "mdr check" "$(db_query "SELECT COUNT(*) FROM merchant_fee_profile WHERE merchant_id=${MID};")" "^1$"

# Transaction with unique txn_ref and positive amount.
db_exec "INSERT INTO merchant_transaction (merchant_id, txn_ref, amount, currency, fee_amount, net_amount, created_by) VALUES (${MID}, 'TXN-S1', 100000, 'IDR', 2500, 97500, 'admin@test.com');"
assert_match "txn row" "$(db_query "SELECT COUNT(*) FROM merchant_transaction WHERE merchant_id=${MID};")" "^1$"
db_exec "INSERT INTO merchant_transaction (merchant_id, txn_ref, amount, currency, created_by) VALUES (${MID}, 'TXN-S1', 1, 'IDR', 'admin@test.com');" 2>/dev/null
assert_match "txn unique" "$(db_query "SELECT COUNT(*) FROM merchant_transaction WHERE merchant_id=${MID};")" "^1$"
db_exec "INSERT INTO merchant_transaction (merchant_id, txn_ref, amount, currency, created_by) VALUES (${MID}, 'TXN-S2', 0, 'IDR', 'admin@test.com');" 2>/dev/null
assert_match "txn amount check" "$(db_query "SELECT COUNT(*) FROM merchant_transaction WHERE merchant_id=${MID};")" "^1$"

# Settlement batch + item linkage.
db_exec "INSERT INTO merchant_settlement (settlement_ref, merchant_id, merchant_name, settlement_type, period_start, period_end, gross_amount, fee_amount, net_amount, currency, status, created_by) VALUES ('STL-S1', ${MID}, 'Toko Maju', 'DAILY', '2026-10-01', '2026-10-31', 100000, 2500, 97500, 'IDR', 'OPEN', 'admin@test.com');"
SID="$(db_query "SELECT id FROM merchant_settlement WHERE settlement_ref='STL-S1';")"
assert_match "settlement inserted" "$SID" "^[0-9]+$"
TXN="$(db_query "SELECT merchant_txn_id FROM merchant_transaction WHERE txn_ref='TXN-S1';")"
db_exec "INSERT INTO merchant_settlement_item (settlement_id, merchant_txn_id, gross_amount, fee_amount, net_amount) VALUES (${SID}, ${TXN}, 100000, 2500, 97500);"
assert_match "item row" "$(db_query "SELECT COUNT(*) FROM merchant_settlement_item WHERE settlement_id=${SID};")" "^1$"
db_exec "INSERT INTO merchant_settlement_item (settlement_id, merchant_txn_id, gross_amount, fee_amount, net_amount) VALUES (${SID}, ${TXN}, 1, 0, 1);" 2>/dev/null
assert_match "item unique" "$(db_query "SELECT COUNT(*) FROM merchant_settlement_item WHERE settlement_id=${SID};")" "^1$"

# Cleanup (items/txn/settlement/profile/merchant).
db_exec "DELETE FROM merchant_settlement_item WHERE settlement_id=${SID};"
db_exec "DELETE FROM merchant_settlement WHERE id=${SID};"
db_exec "DELETE FROM merchant_transaction WHERE merchant_id=${MID};"
db_exec "DELETE FROM merchant_fee_profile WHERE merchant_id=${MID};"
db_exec "DELETE FROM merchant WHERE id=${MID};"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
