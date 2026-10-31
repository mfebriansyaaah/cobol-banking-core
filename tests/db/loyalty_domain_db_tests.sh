#!/usr/bin/env bash
# Loyalty core lifecycle (PR-802): create/activate/enroll/earn/redeem/expire/adjust.
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
db_reset_loyalty_domain
db_exec "INSERT INTO customer (customer_ref, full_name, customer_type, credit_limit, used_credit, status, kyc_status, created_by) VALUES ('CUST-LOYD','Loy D','INDIVIDUAL',100000,0,'ONBOARDED','APPROVED','admin@test.com') ON DUPLICATE KEY UPDATE status='ONBOARDED';"

# CREATE happy path + guards.
out="$(run_cobol "LOY_CREATE|PROG-D1|Program D1|2.0000:0.1000:IDR|2026-01-01:2026-12-31|POINT|admin@test.com")"
assert_match "create ok" "$out" "SUCCESS\|LOY_CREATE\|[0-9]+"
pid="$(printf '%s' "$out" | awk -F'|' '{print $3}')"
assert_match "draft persisted" "$(db_query "SELECT status FROM loyalty_program WHERE id=${pid};")" "^DRAFT$"
assert_match "earn rate stored" "$(db_query "SELECT earn_rate FROM loyalty_program WHERE id=${pid};")" "^2.0000$"
assert_match "duplicate code" "$(run_cobol "LOY_CREATE|PROG-D1|X|1:0.1:IDR|:|POINT|admin@test.com")" "ERROR\|DUPLICATE"
assert_match "negative earn" "$(run_cobol "LOY_CREATE|PROG-DX|X|-1:0.1:IDR|:|POINT|admin@test.com")" "ERROR\|INVALID_AMOUNT"

# ENROLL blocked before ACTIVATE; unknown customer; then activate + enroll.
assert_match "enroll before activate" "$(run_cobol "LOY_ENROLL|${pid}|CUST-LOYD|GOLD|||admin@test.com")" "ERROR\|INVALID_STATE"
assert_match "activate" "$(run_cobol "LOY_ACTIVATE|${pid}|||||admin@test.com")" "SUCCESS\|LOY_ACTIVATE"
assert_match "active persisted" "$(db_query "SELECT status FROM loyalty_program WHERE id=${pid};")" "^ACTIVE$"
assert_match "activate twice invalid" "$(run_cobol "LOY_ACTIVATE|${pid}|||||admin@test.com")" "ERROR\|INVALID_STATE"
assert_match "unknown customer" "$(run_cobol "LOY_ENROLL|${pid}|NO-SUCH-CUST||||admin@test.com")" "ERROR\|NOT_FOUND"
out2="$(run_cobol "LOY_ENROLL|${pid}|CUST-LOYD|GOLD|||admin@test.com")"
assert_match "enroll ok" "$out2" "SUCCESS\|LOY_ENROLL\|[0-9]+"
mid="$(printf '%s' "$out2" | awk -F'|' '{print $3}')"
assert_match "member active" "$(db_query "SELECT status FROM loyalty_member WHERE member_id=${mid};")" "^ACTIVE$"
assert_match "duplicate enroll" "$(run_cobol "LOY_ENROLL|${pid}|CUST-LOYD||||admin@test.com")" "ERROR\|DUPLICATE"

# EARN happy path + guards.
assert_match "earn ok" "$(run_cobol "LOY_EARN|${mid}|CARD_TXN|TXN-D1|100|2020-01-01|admin@test.com")" "SUCCESS\|LOY_EARN\|200"
assert_match "balance 200" "$(db_query "SELECT points_balance FROM loyalty_member WHERE member_id=${mid};")" "^200.0000$"
assert_match "ledger row" "$(db_query "SELECT COUNT(*) FROM loyalty_points_ledger WHERE member_id=${mid} AND source_ref='TXN-D1';")" "^1$"
assert_match "duplicate source" "$(run_cobol "LOY_EARN|${mid}|CARD_TXN|TXN-D1|100||admin@test.com")" "ERROR\|DUPLICATE"
assert_match "bad source type" "$(run_cobol "LOY_EARN|${mid}|REDEMPTION|X|100||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "zero amount" "$(run_cobol "LOY_EARN|${mid}|CARD_TXN|TXN-D0|0||admin@test.com")" "ERROR\|INVALID_AMOUNT"
assert_match "negative amount" "$(run_cobol "LOY_EARN|${mid}|CARD_TXN|TXN-DN|-5||admin@test.com")" "ERROR\|INVALID_AMOUNT"
assert_match "unknown member" "$(run_cobol "LOY_EARN|999999999|CARD_TXN|TXN-Z|100||admin@test.com")" "ERROR\|NOT_FOUND"
assert_match "validate preview" "$(run_cobol "LOY_VALIDATE|${pid}|50||||admin@test.com")" "SUCCESS\|LOY_VALID\|100"

# REDEEM happy path + guards.
assert_match "redeem ok" "$(run_cobol "LOY_REDEEM|${mid}|80|VOUCHER-D1|||admin@test.com")" "SUCCESS\|LOY_REDEEM\|[0-9]+"
assert_match "balance 120" "$(db_query "SELECT points_balance FROM loyalty_member WHERE member_id=${mid};")" "^120.0000$"
assert_match "redemption approved" "$(db_query "SELECT status FROM loyalty_redemption WHERE member_id=${mid};")" "^APPROVED$"
assert_match "redeem over balance" "$(run_cobol "LOY_REDEEM|${mid}|500|X|||admin@test.com")" "ERROR\|LIMIT"

# EXPIRE: earn 300 (no expiry), expire the 200-pt TXN-D1 row.
assert_match "earn more" "$(run_cobol "LOY_EARN|${mid}|PAYMENT|PAY-D2|150||admin@test.com")" "SUCCESS\|LOY_EARN\|300"
assert_match "expire ok" "$(run_cobol "LOY_EXPIRE|${mid}|2026-06-01||||admin@test.com")" "SUCCESS\|LOY_EXPIRE\|200"
assert_match "balance 220" "$(db_query "SELECT points_balance FROM loyalty_member WHERE member_id=${mid};")" "^220.0000$"
assert_match "expire again empty" "$(run_cobol "LOY_EXPIRE|${mid}|2026-06-01||||admin@test.com")" "SUCCESS\|LOY_EXPIRE\|0"

# ADJUST: +50, over-draw rejected, -30.
assert_match "adjust up" "$(run_cobol "LOY_ADJUST|${mid}|50|bonus fix|||admin@test.com")" "SUCCESS\|LOY_ADJUST\|270"
assert_match "adjust overdraw" "$(run_cobol "LOY_ADJUST|${mid}|-500|too much|||admin@test.com")" "ERROR\|LIMIT"
assert_match "adjust down" "$(run_cobol "LOY_ADJUST|${mid}|-30|clawback|||admin@test.com")" "SUCCESS\|LOY_ADJUST\|240"

# Consistency: ledger sum == member balance; reads; auth.
assert_match "ledger consistent" "$(db_query "SELECT IF((SELECT points_balance FROM loyalty_member WHERE member_id=${mid}) = (SELECT COALESCE(SUM(points_delta),0) FROM loyalty_points_ledger WHERE member_id=${mid}),'OK','MISMATCH');")" "^OK$"
assert_match "get member" "$(run_cobol "LOY_GET|${mid}|||||admin@test.com")" "SUCCESS\|LOY_GET\|${mid}\|"
assert_match "summary ok" "$(run_cobol "LOY_SUMMARY||||||admin@test.com")" "SUCCESS\|LOY_SUMMARY"
assert_match "audit ok" "$(run_cobol "LOY_AUDIT||50|0|||admin@test.com")" "SUCCESS\|LOY_AUDIT"
assert_match "audit rows" "$(db_query "SELECT COUNT(*) FROM loyalty_audit WHERE member_id=${mid};")" "^[1-9]"
assert_match "non-admin refused" "$(run_cobol "LOY_EARN|${mid}|CARD_TXN|TXN-Z|1||sender@test.com")" "ERROR\|FORBIDDEN"

# Cleanup.
db_exec "DELETE FROM loyalty_audit WHERE program_id=${pid};"
db_exec "DELETE FROM loyalty_redemption WHERE member_id=${mid};"
db_exec "DELETE FROM loyalty_points_ledger WHERE member_id=${mid};"
db_exec "DELETE FROM loyalty_member WHERE member_id=${mid};"
db_exec "DELETE FROM loyalty_campaign WHERE program_id=${pid};"
db_exec "DELETE FROM loyalty_program_audit WHERE loyalty_program_id=${pid};"
db_exec "DELETE FROM loyalty_program WHERE id=${pid};"
db_exec "DELETE FROM customer WHERE customer_ref='CUST-LOYD';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
