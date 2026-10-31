#!/usr/bin/env bash
# Integration: loyalty program -> enroll -> earn -> GL liability -> redeem -> expire.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
if ! db_available; then echo "SKIP: DB unavailable"; exit 0; fi

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

db_seed
db_reset_loyalty_domain
db_exec "INSERT INTO customer (customer_ref, full_name, customer_type, credit_limit, used_credit, status, kyc_status, created_by) VALUES ('CUST-LOYI','Loy Int','INDIVIDUAL',100000,0,'ONBOARDED','APPROVED','admin@test.com') ON DUPLICATE KEY UPDATE status='ONBOARDED';"
ADMIN="loyint@test.com"
db_exec "INSERT INTO users (email, password_hash, full_name, dob, status, role) VALUES ('$ADMIN', CONCAT('SHA256_',SHA2('secret123',256)), 'Loy Int', '1990-01-01', 'VERIFIED', 'SUPER_ADMIN') ON DUPLICATE KEY UPDATE role='SUPER_ADMIN', status='VERIFIED';"

echo "=== Loyalty integration (program -> earn -> GL -> redeem -> expire) ==="

OUT=$(run_cobol "LOY_CREATE|PROG-INT|Program Int|2.0000:0.1000:IDR|2026-01-01:2026-12-31|POINT|$ADMIN")
assert_match "create" "$OUT" "SUCCESS\|LOY_CREATE"
PID=$(printf '%s' "$OUT" | awk -F'|' '{print $3}')
assert_match "draft" "$(db_query "SELECT status FROM loyalty_program WHERE id=${PID};")" "^DRAFT$"
assert_match "activate" "$(run_cobol "LOY_ACTIVATE|${PID}|||||$ADMIN")" "SUCCESS\|LOY_ACTIVATE"

MOUT=$(run_cobol "LOY_ENROLL|${PID}|CUST-LOYI|GOLD|||$ADMIN")
assert_match "enroll" "$MOUT" "SUCCESS\|LOY_ENROLL"
MID=$(printf '%s' "$MOUT" | awk -F'|' '{print $3}')

assert_match "earn 200" "$(run_cobol "LOY_EARN|${MID}|CARD_TXN|TXN-INT-1|100|2020-01-01|$ADMIN")" "SUCCESS\|LOY_EARN\|200"
assert_match "balance 200" "$(db_query "SELECT points_balance FROM loyalty_member WHERE member_id=${MID};")" "^200"

# Liability: 200 pts x burn 0.1000 = 20 IDR (debit rewards expense 5000, credit liability 1100).
GOUT=$(run_cobol "GL_JOURNAL_POST|2026-10-30|Loyalty PROG-INT earn|5000|1100|IDR:20|$ADMIN")
assert_match "gl posted" "$GOUT" "SUCCESS\|GL_POSTED"
GJ=$(db_query "SELECT id FROM gl_journal ORDER BY id DESC LIMIT 1;")
assert_match "gl balanced" "$(db_query "SELECT IF(SUM(debit_amount)=SUM(credit_amount) AND SUM(debit_amount)>0,'BALANCED','UNBALANCED') FROM gl_journal_line WHERE journal_id=${GJ};")" "^BALANCED$"

assert_match "redeem 80" "$(run_cobol "LOY_REDEEM|${MID}|80|VOUCHER-INT|${GJ}||$ADMIN")" "SUCCESS\|LOY_REDEEM"
assert_match "gl linked" "$(db_query "SELECT gl_journal_id FROM loyalty_redemption WHERE member_id=${MID};")" "^${GJ}$"
assert_match "earn 300" "$(run_cobol "LOY_EARN|${MID}|PAYMENT|PAY-INT-2|150||$ADMIN")" "SUCCESS\|LOY_EARN\|300"
assert_match "expire 200" "$(run_cobol "LOY_EXPIRE|${MID}|2026-06-01||||$ADMIN")" "SUCCESS\|LOY_EXPIRE\|200"
assert_match "balance 220" "$(db_query "SELECT points_balance FROM loyalty_member WHERE member_id=${MID};")" "^220"
assert_match "ledger consistent" "$(db_query "SELECT IF((SELECT points_balance FROM loyalty_member WHERE member_id=${MID}) = (SELECT COALESCE(SUM(points_delta),0) FROM loyalty_points_ledger WHERE member_id=${MID}),'OK','MISMATCH');")" "^OK$"
assert_match "audit rows" "$(db_query "SELECT COUNT(*) FROM loyalty_audit WHERE member_id=${MID};")" "^[1-9]"

# Cleanup.
db_exec "DELETE FROM loyalty_audit WHERE program_id=${PID};"
db_exec "DELETE FROM loyalty_redemption WHERE member_id=${MID};"
db_exec "DELETE FROM loyalty_points_ledger WHERE member_id=${MID};"
db_exec "DELETE FROM loyalty_member WHERE member_id=${MID};"
db_exec "DELETE FROM loyalty_campaign WHERE program_id=${PID};"
db_exec "DELETE FROM loyalty_program_audit WHERE loyalty_program_id=${PID};"
db_exec "DELETE FROM loyalty_program WHERE id=${PID};"
db_exec "DELETE FROM customer WHERE customer_ref='CUST-LOYI';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
