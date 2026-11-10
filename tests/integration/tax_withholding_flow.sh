#!/usr/bin/env bash
# Integration: deposit interest + fee -> tax withholding -> GL -> report.
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
db_reset_tax_management
db_exec "DELETE FROM customer WHERE customer_ref='CUST-TAXI';"
db_exec "INSERT INTO customer (customer_ref, full_name, customer_type, credit_limit, used_credit, status, kyc_status, created_by) VALUES ('CUST-TAXI','PT Tax','CORPORATE',1000000,0,'ONBOARDED','APPROVED','admin@test.com');"
ADMIN="taxint@test.com"
db_exec "INSERT INTO users (email, password_hash, full_name, dob, status, role) VALUES ('$ADMIN', CONCAT('SHA256_',SHA2('secret123',256)), 'Tax Int', '1990-01-01', 'VERIFIED', 'SUPER_ADMIN') ON DUPLICATE KEY UPDATE role='SUPER_ADMIN', status='VERIFIED';"
db_exec "INSERT INTO users (email, password_hash, full_name, dob, status, role) VALUES ('taxintpool@test.com', CONCAT('SHA256_',SHA2('secret123',256)), 'Tax Pool', '1990-01-01', 'VERIFIED', 'USER') ON DUPLICATE KEY UPDATE status='VERIFIED';"
IDR="$(db_query "SELECT currency_id FROM currencies WHERE iso_code='IDR';")"
# Fase 2: DEP_OPEN funds the deposit, so the opener holds the principal in
# an IDR wallet and a bank-owned IDR DEPOSIT_POOL exists (GL period is
# already required open by the GL posts below).
db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${ADMIN}','taxintpool@test.com')));"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${ADMIN}','taxintpool@test.com'));"
db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, ${IDR}, 1000000.00 FROM users WHERE email='${ADMIN}';"
db_exec "INSERT INTO accounts (user_id, currency_id, account_type, balance) SELECT id, ${IDR}, 'DEPOSIT_POOL', 1000000.00 FROM users WHERE email='taxintpool@test.com';"
PERIOD="$(db_query "SELECT DATE_FORMAT(NOW(),'%Y-%m');")"

echo "=== Tax withholding integration (deposit + fee) ==="
# GL posting date must fall in an OPEN period (gl_period holds the current month).
GL_DATE="$(date +%F)"

# Rule: 10% no threshold, gl 5000.
ROUT=$(run_cobol "TXM_RULE_CREATE|TXR-INT|PPh 21|WITHHOLDING|10:0:0:0|IDR:5000:2026-01-01:|admin@test.com")
assert_match "rule create" "$ROUT" "SUCCESS\|TXM_RULE_CREATE"
RID=$(printf '%s' "$ROUT" | awk -F'|' '{print $3}')

# Deposit path: open -> accrue -> withhold interest.
DOUT=$(run_cobol "DEP_OPEN|${ADMIN}|1000000|IDR|12|6.00|admin@test.com")
DID=$(printf '%s' "$DOUT" | awk -F'|' '{print $3}')
assert_match "deposit open" "$DOUT" "SUCCESS\|DEP_OPEN"
ACCRUE=$(run_cobol "DEP_ACCRUE|${DID}|30||||admin@test.com")
assert_match "accrue" "$ACCRUE" "SUCCESS\|DEP_ACCRUE"
INTEREST=$(printf '%s' "$ACCRUE" | awk -F'|' '{print $3}' | grep -oE '[0-9]+\.?[0-9]*' | head -1)
assert_match "interest parsed" "$INTEREST" "^[0-9]"
COUT=$(run_cobol "TXM_CALC|${RID}|DEPOSIT_INTEREST|DEPINT-${DID}|${INTEREST}|IDR|admin@test.com")
assert_match "calc deposit tax" "$COUT" "SUCCESS\|TXM_CALC"
DEID=$(printf '%s' "$COUT" | awk -F'|' '{print $3}')
TAX1=$(printf '%s' "$COUT" | awk -F'|' '{print $4}')
GOUT=$(run_cobol "GL_JOURNAL_POST|${GL_DATE}|Tax deposit ${DID}|5000|1100|IDR:${TAX1}|admin@test.com")
assert_match "gl posted" "$GOUT" "SUCCESS\|GL_POSTED"
GJ1=$(db_query "SELECT id FROM gl_journal ORDER BY id DESC LIMIT 1;")
assert_match "post deposit tax" "$(run_cobol "TXM_POST|${DEID}|${GJ1}||||admin@test.com")" "SUCCESS\|TXM_POST"

# Fee path: seed flat fee rule, calculate, withhold.
db_exec "INSERT INTO fee_rule (rule_code, name, fee_type, currency_code, flat_amount, percent_rate, min_amount, max_amount, priority, enabled, created_by) VALUES ('FEE_TAXI','Int fee','FLAT','IDR',5000,0,0,0,100,TRUE,'admin@test.com') ON DUPLICATE KEY UPDATE enabled=TRUE;"
FOUT=$(run_cobol "FEE_CALCULATE|${ADMIN}|FEE_TAXI|100000|IDR||admin@test.com")
assert_match "fee calc" "$FOUT" "SUCCESS\|FEE_CALC"
FEEAMT=$(printf '%s' "$FOUT" | awk -F'|' '{print $3}' | grep -oE '[0-9]+\.?[0-9]*' | head -1)
FOUT2=$(run_cobol "TXM_CALC|${RID}|FEE|FEE-TAXI-1|${FEEAMT}|IDR|admin@test.com")
assert_match "calc fee tax" "$FOUT2" "SUCCESS\|TXM_CALC"
FEID=$(printf '%s' "$FOUT2" | awk -F'|' '{print $3}')
TAX2=$(printf '%s' "$FOUT2" | awk -F'|' '{print $4}')
GOUT2=$(run_cobol "GL_JOURNAL_POST|${GL_DATE}|Tax fee|5000|1100|IDR:${TAX2}|admin@test.com")
assert_match "gl posted fee" "$GOUT2" "SUCCESS\|GL_POSTED"
GJ2=$(db_query "SELECT id FROM gl_journal ORDER BY id DESC LIMIT 1;")
assert_match "post fee tax" "$(run_cobol "TXM_POST|${FEID}|${GJ2}||||admin@test.com")" "SUCCESS\|TXM_POST"

# Report aggregates both POSTED entries.
ROUT2=$(run_cobol "TXM_REPORT|${PERIOD}|WITHHOLDING|IDR|||admin@test.com")
assert_match "report" "$ROUT2" "SUCCESS\|TXM_REPORT"
TOTALS="$(db_query "SELECT CONCAT(total_base,'|',total_tax) FROM tax_report_run WHERE period='${PERIOD}' AND tax_type='WITHHOLDING' AND currency='IDR';")"
assert_match "report totals present" "$TOTALS" "^[0-9]"

# Cleanup (keep shared gl journals; remove test-scoped rows).
db_exec "DELETE FROM tax_withholding_entry WHERE source_ref LIKE 'DEPINT-%' OR source_ref LIKE 'FEE-TAXI-%';"
db_exec "DELETE FROM tax_report_run WHERE period='${PERIOD}' AND tax_type='WITHHOLDING';"
db_exec "DELETE FROM tax_audit WHERE detail LIKE 'DEPINT-%' OR detail LIKE 'FEE-TAXI%';"
db_exec "DELETE FROM tax_management WHERE tax_ref='TXR-INT';"
db_exec "DELETE FROM fee_rule WHERE rule_code='FEE-TAXI';"
db_exec "DELETE FROM ledger WHERE txn_ref='DEP-${DID}-FUND';"
db_exec "DELETE FROM deposit_transaction WHERE deposit_id=${DID};"
db_exec "DELETE FROM deposit_accrual WHERE deposit_id=${DID};"
db_exec "DELETE FROM deposit_account WHERE id=${DID};"
db_exec "DELETE FROM journal_entries WHERE txn_ref='DEP-${DID}-FUND';"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${ADMIN}','taxintpool@test.com'));"
db_exec "DELETE FROM users WHERE email='taxintpool@test.com';"
db_exec "DELETE FROM customer WHERE customer_ref='CUST-TAXI';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
