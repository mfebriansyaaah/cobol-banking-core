#!/usr/bin/env bash
# Loyalty schema/constraint tests (PR-801).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
require_db

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

db_seed
db_reset_loyalty_domain

# Program with domain columns.
db_exec "INSERT INTO loyalty_program (loyalty_ref, program_code, name, type, earn_rate, burn_rate, currency, start_date, end_date, status, created_by) VALUES ('LYP-S1','PROG-S1','Program S1','POINT',1.0000,0.1000,'IDR','2026-01-01','2026-12-31','ACTIVE','admin@test.com');"
PID="$(db_query "SELECT id FROM loyalty_program WHERE loyalty_ref='LYP-S1';")"
assert_match "program inserted" "$PID" "^[0-9]+$"
assert_match "earn rate stored" "$(db_query "SELECT earn_rate FROM loyalty_program WHERE id=${PID};")" "^1.0000$"
assert_match "program code unique" "$(db_query "SELECT COUNT(*) FROM loyalty_program WHERE program_code='PROG-S1';")" "^1$"
db_exec "INSERT INTO loyalty_program (loyalty_ref, program_code, name, type, created_by) VALUES ('LYP-S1B','PROG-S1','X','POINT','admin@test.com');" 2>/dev/null
assert_match "program code unique enforced" "$(db_query "SELECT COUNT(*) FROM loyalty_program WHERE program_code='PROG-S1';")" "^1$"

# Member: one row per program+customer, balance non-negative.
db_exec "INSERT INTO loyalty_member (program_id, customer_ref, tier, points_balance, status) VALUES (${PID}, 'CUST-LS1', 'GOLD', 100, 'ACTIVE');"
MID="$(db_query "SELECT member_id FROM loyalty_member WHERE program_id=${PID} AND customer_ref='CUST-LS1';")"
assert_match "member inserted" "$MID" "^[0-9]+$"
db_exec "INSERT INTO loyalty_member (program_id, customer_ref) VALUES (${PID}, 'CUST-LS1');" 2>/dev/null
assert_match "member unique" "$(db_query "SELECT COUNT(*) FROM loyalty_member WHERE program_id=${PID} AND customer_ref='CUST-LS1';")" "^1$"
db_exec "INSERT INTO loyalty_member (program_id, customer_ref, points_balance) VALUES (${PID}, 'CUST-NEG', -5);" 2>/dev/null
assert_match "balance check" "$(db_query "SELECT COUNT(*) FROM loyalty_member WHERE customer_ref='CUST-NEG';")" "^0$"

# Ledger: one row per member+source, balance_after non-negative.
db_exec "INSERT INTO loyalty_points_ledger (member_id, source_type, source_ref, points_delta, balance_after, created_by) VALUES (${MID}, 'CARD_TXN', 'TXN-S1', 100, 100, 'admin@test.com');"
assert_match "ledger row" "$(db_query "SELECT COUNT(*) FROM loyalty_points_ledger WHERE member_id=${MID};")" "^1$"
db_exec "INSERT INTO loyalty_points_ledger (member_id, source_type, source_ref, points_delta, balance_after, created_by) VALUES (${MID}, 'CARD_TXN', 'TXN-S1', 100, 200, 'admin@test.com');" 2>/dev/null
assert_match "source unique" "$(db_query "SELECT COUNT(*) FROM loyalty_points_ledger WHERE member_id=${MID};")" "^1$"

# Redemption with points > 0, campaign row.
db_exec "INSERT INTO loyalty_redemption (member_id, points, reward_code, status) VALUES (${MID}, 50, 'VOUCHER-10', 'REQUESTED');"
assert_match "redemption row" "$(db_query "SELECT COUNT(*) FROM loyalty_redemption WHERE member_id=${MID};")" "^1$"
db_exec "INSERT INTO loyalty_campaign (program_id, name, bonus_points, status) VALUES (${PID}, 'Bonus S1', 25, 'ACTIVE');"
assert_match "campaign row" "$(db_query "SELECT COUNT(*) FROM loyalty_campaign WHERE program_id=${PID};")" "^1$"

# Cleanup (children first).
db_exec "DELETE FROM loyalty_audit WHERE program_id=${PID};"
db_exec "DELETE FROM loyalty_redemption WHERE member_id=${MID};"
db_exec "DELETE FROM loyalty_points_ledger WHERE member_id=${MID};"
db_exec "DELETE FROM loyalty_member WHERE member_id=${MID};"
db_exec "DELETE FROM loyalty_campaign WHERE program_id=${PID};"
db_exec "DELETE FROM loyalty_program_audit WHERE loyalty_program_id=${PID};"
db_exec "DELETE FROM loyalty_program WHERE id=${PID};"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
