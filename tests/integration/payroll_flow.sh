#!/usr/bin/env bash
# Integration: payroll batch -> validate -> approve -> process (tax) -> GL -> pay -> close.
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
db_reset_payroll_processing
db_exec "DELETE FROM customer WHERE customer_ref='CUST-PAYI';"
db_exec "INSERT INTO customer (customer_ref, full_name, customer_type, credit_limit, used_credit, status, kyc_status, created_by) VALUES ('CUST-PAYI','PT Pay','CORPORATE',1000000,0,'ONBOARDED','APPROVED','admin@test.com');"
ADMIN="payint@test.com"
db_exec "INSERT INTO users (email, password_hash, full_name, dob, status, role) VALUES ('$ADMIN', CONCAT('SHA256_',SHA2('secret123',256)), 'Pay Int', '1990-01-01', 'VERIFIED', 'SUPER_ADMIN') ON DUPLICATE KEY UPDATE role='SUPER_ADMIN', status='VERIFIED';"
# Self-sufficient funding account: PRL_PROCESS requires the batch source
# account to cover total net (57000 here). Never use an ambient account:
# balances vary per database, and on a fresh DB the richest seeded account
# holds 1000, so PRL_PROCESS fails with ERROR|BALANCE. The matching ledger
# row keeps balance == ledger sum for reconciliation checks.
ADMIN_UID="$(db_query "SELECT id FROM users WHERE email='$ADMIN';")"
db_exec "INSERT INTO accounts (user_id, currency_id, account_type, balance, status) VALUES (${ADMIN_UID}, 1, 'SAVINGS', 1000000.00, 'ACTIVE') ON DUPLICATE KEY UPDATE balance=1000000.00, status='ACTIVE';"
ACC="$(db_query "SELECT account_id FROM accounts WHERE user_id=${ADMIN_UID} AND currency_id=1;")"
db_exec "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description) SELECT CONCAT('SEED-PAYI-', ${ACC}), ${ACC}, 1000000.00, 'CREDIT', 1, 'Payroll funding' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM ledger WHERE account_id=${ACC});"
db_exec "INSERT INTO tax_management (tax_ref, rule_code, tax_name, tax_type, max_tax, rate_pct, fixed_amount, threshold_amount, currency, status, created_by) VALUES ('TXR-PINT','PPH-INT','PPh 21','WITHHOLDING',0,5,0,0,'IDR','ACTIVE','admin@test.com');"
RID="$(db_query "SELECT id FROM tax_management WHERE tax_ref='TXR-PINT';")"

echo "=== Payroll integration (batch -> tax -> GL -> pay) ==="
# GL posting date must fall in an OPEN period (gl_period holds the current month).
GL_DATE="$(date +%F)"

OUT=$(run_cobol "PRL_CREATE|PAY-INT-1|Gaji Jan|MONTHLY|CUST-PAYI|${ACC}|$ADMIN")
assert_match "create with company+account" "$OUT" "SUCCESS\|PRL_CREATE"
BID=$(printf '%s' "$OUT" | awk -F'|' '{print $3}')
assert_match "company stored" "$(db_query "SELECT company_customer_ref FROM payroll_processing WHERE id=${BID};")" "^CUST-PAYI$"

assert_match "add emp1" "$(run_cobol "PRL_ADD_ITEM|${BID}|E-INT-1|Ani|40000|${ACC}|$ADMIN")" "SUCCESS\|PRL_ADD_ITEM"
assert_match "add emp2" "$(run_cobol "PRL_ADD_ITEM|${BID}|E-INT-2|Budi|20000|${ACC}|$ADMIN")" "SUCCESS\|PRL_ADD_ITEM"
assert_match "validate" "$(run_cobol "PRL_VALIDATE|${BID}|||||$ADMIN")" "SUCCESS\|PRL_VALIDATE"
assert_match "approve" "$(run_cobol "PRL_APPROVE|${BID}|||||$ADMIN")" "SUCCESS\|PRL_APPROVE"
assert_match "process" "$(run_cobol "PRL_PROCESS|${BID}|${RID}||||$ADMIN")" "SUCCESS\|PRL_PROCESS"
assert_match "tax total" "$(db_query "SELECT total_tax FROM payroll_processing WHERE id=${BID};")" "^3000"
assert_match "net total" "$(db_query "SELECT total_net FROM payroll_processing WHERE id=${BID};")" "^57000"

# GL: salary expense 570k + tax payable via tax entry is separate domain;
# here post net payout (debit salary expense 5000, credit cash 1000).
GOUT=$(run_cobol "GL_JOURNAL_POST|${GL_DATE}|Payroll PAY-INT-1|5000|1000|IDR:57000|$ADMIN")
assert_match "gl posted" "$GOUT" "SUCCESS\|GL_POSTED"
GJ=$(db_query "SELECT id FROM gl_journal ORDER BY id DESC LIMIT 1;")
assert_match "gl balanced" "$(db_query "SELECT IF(SUM(debit_amount)=SUM(credit_amount) AND SUM(debit_amount)>0,'BALANCED','UNBALANCED') FROM gl_journal_line WHERE journal_id=${GJ};")" "^BALANCED$"

assert_match "pay" "$(run_cobol "PRL_PAY|${BID}|PMC-PAYI||||$ADMIN")" "SUCCESS\|PRL_PAY"
assert_match "paid" "$(db_query "SELECT status FROM payroll_processing WHERE id=${BID};")" "^PAID$"
assert_match "close" "$(run_cobol "PRL_CLOSE|${BID}|Done||||$ADMIN")" "SUCCESS\|PRL_CLOSE"
assert_match "closed" "$(db_query "SELECT status FROM payroll_processing WHERE id=${BID};")" "^CLOSED$"

# Cleanup.
db_exec "DELETE FROM payroll_payment WHERE batch_id=${BID};"
db_exec "DELETE FROM payroll_item WHERE batch_id=${BID};"
db_exec "DELETE FROM payroll_employee WHERE batch_id=${BID};"
db_exec "DELETE FROM payroll_audit WHERE batch_id=${BID};"
db_exec "DELETE FROM payroll_processing WHERE id=${BID};"
db_exec "DELETE FROM tax_audit WHERE detail LIKE 'PAY-INT%';"
db_exec "DELETE FROM tax_management WHERE tax_ref='TXR-PINT';"
db_exec "DELETE FROM customer WHERE customer_ref='CUST-PAYI';"
db_exec "DELETE FROM ledger WHERE account_id=${ACC};"
db_exec "DELETE FROM accounts WHERE account_id=${ACC};"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
