#!/usr/bin/env bash
# Payroll core lifecycle (PR-602): add/validate/approve/process/pay/close + tax/GL hooks.
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
db_exec "DELETE FROM customer WHERE customer_ref='CUST-PAYD';"
db_exec "INSERT INTO customer (customer_ref, full_name, customer_type, credit_limit, used_credit, status, kyc_status, created_by) VALUES ('CUST-PAYD','PT Pay','CORPORATE',1000000,0,'ONBOARDED','APPROVED','admin@test.com');"

# Batch via legacy CREATE (OPEN doubles as draft).
out="$(run_cobol "PRL_CREATE|PAY-D1|Gaji Jan|MONTHLY|||admin@test.com")"
assert_match "create ok" "$out" "SUCCESS\|PRL_CREATE\|[0-9]+"
id="$(printf '%s' "$out" | awk -F'|' '{print $3}')"
ACC="$(db_query "SELECT account_id FROM accounts LIMIT 1;")"
db_exec "UPDATE payroll_processing SET company_customer_ref='CUST-PAYD', source_account_id=${ACC}, currency='IDR', period_start='2026-01-01', period_end='2026-01-31' WHERE id=${id};"

# ADD_ITEM guards.
assert_match "add item" "$(run_cobol "PRL_ADD_ITEM|${id}|EMP-1|Budi|500|${ACC}|admin@test.com")" "SUCCESS\|PRL_ADD_ITEM\|[0-9]+"
assert_match "add second" "$(run_cobol "PRL_ADD_ITEM|${id}|EMP-2|Siti|300|${ACC}|admin@test.com")" "SUCCESS\|PRL_ADD_ITEM\|[0-9]+"
assert_match "duplicate employee" "$(run_cobol "PRL_ADD_ITEM|${id}|EMP-1|X|1|${ACC}|admin@test.com")" "ERROR\|DUPLICATE"
assert_match "bad amount" "$(run_cobol "PRL_ADD_ITEM|${id}|EMP-X|X|0|${ACC}|admin@test.com")" "ERROR\|INVALID_AMOUNT"
assert_match "unknown account" "$(run_cobol "PRL_ADD_ITEM|${id}|EMP-X|X|100|999999999|admin@test.com")" "ERROR\|NOT_FOUND"

# VALIDATE: DRAFT/OPEN -> VALIDATED, employees PENDING -> VALID.
assert_match "validate" "$(run_cobol "PRL_VALIDATE|${id}|||||admin@test.com")" "SUCCESS\|PRL_VALIDATE"
assert_match "validated" "$(db_query "SELECT status FROM payroll_processing WHERE id=${id};")" "^VALIDATED$"
assert_match "employees valid" "$(db_query "SELECT COUNT(*) FROM payroll_employee WHERE batch_id=${id} AND status='VALID';")" "^2$"
assert_match "validate twice invalid" "$(run_cobol "PRL_VALIDATE|${id}|||||admin@test.com")" "ERROR\|INVALID_STATE"

# APPROVE + PROCESS with 10% tax rule.
assert_match "approve" "$(run_cobol "PRL_APPROVE|${id}|||||admin@test.com")" "SUCCESS\|PRL_APPROVE"
assert_match "approved" "$(db_query "SELECT status FROM payroll_processing WHERE id=${id};")" "^APPROVED$"
db_exec "INSERT INTO tax_management (tax_ref, rule_code, tax_name, tax_type, max_tax, rate_pct, fixed_amount, threshold_amount, currency, status, created_by) VALUES ('TXR-PD','PPH-PD','PPh','WITHHOLDING',0,10,0,0,'IDR','ACTIVE','admin@test.com');"
RID="$(db_query "SELECT id FROM tax_management WHERE tax_ref='TXR-PD';")"
assert_match "process" "$(run_cobol "PRL_PROCESS|${id}|${RID}||||admin@test.com")" "SUCCESS\|PRL_PROCESS"
assert_match "processing" "$(db_query "SELECT status FROM payroll_processing WHERE id=${id};")" "^PROCESSING$"
assert_match "tax applied" "$(db_query "SELECT SUM(tax_amount) FROM payroll_employee WHERE batch_id=${id};")" "^80"
assert_match "net applied" "$(db_query "SELECT total_net FROM payroll_processing WHERE id=${id};")" "^720"
assert_match "payments created" "$(db_query "SELECT COUNT(*) FROM payroll_payment WHERE batch_id=${id} AND status='PENDING';")" "^2$"

# Unknown tax rule (fresh APPROVED batch) + insufficient balance guards.
out2="$(run_cobol "PRL_CREATE|PAY-D2|Gaji|MONTHLY|||admin@test.com")"
id2="$(printf '%s' "$out2" | awk -F'|' '{print $3}')"
db_exec "UPDATE payroll_processing SET company_customer_ref='CUST-PAYD', source_account_id=${ACC} WHERE id=${id2};"
run_cobol "PRL_ADD_ITEM|${id2}|E1|X|999999|${ACC}|admin@test.com" >/dev/null
run_cobol "PRL_VALIDATE|${id2}|||||admin@test.com" >/dev/null
run_cobol "PRL_APPROVE|${id2}|||||admin@test.com" >/dev/null
assert_match "unknown rule" "$(run_cobol "PRL_PROCESS|${id2}|999999||||admin@test.com")" "ERROR\|NOT_FOUND"
assert_match "insufficient balance" "$(run_cobol "PRL_PROCESS|${id2}|${RID}||||admin@test.com")" "ERROR\|BALANCE"
assert_match "pay before process invalid" "$(run_cobol "PRL_PAY|${id2}|||||admin@test.com")" "ERROR\|INVALID_STATE"
db_exec "DELETE FROM payroll_employee WHERE batch_id=${id2}; DELETE FROM payroll_processing WHERE id=${id2};"
assert_match "pay" "$(run_cobol "PRL_PAY|${id}|PMC-PAY1||||admin@test.com")" "SUCCESS\|PRL_PAY"
assert_match "paid" "$(db_query "SELECT status FROM payroll_processing WHERE id=${id};")" "^PAID$"
assert_match "pmc linked" "$(db_query "SELECT DISTINCT payment_clearing_ref FROM payroll_payment WHERE batch_id=${id};")" "^PMC-PAY1$"
assert_match "employees paid" "$(db_query "SELECT COUNT(*) FROM payroll_employee WHERE batch_id=${id} AND status='PAID';")" "^2$"
assert_match "close" "$(run_cobol "PRL_CLOSE|${id}|Selesai||||admin@test.com")" "SUCCESS\|PRL_CLOSE"
assert_match "closed" "$(db_query "SELECT status FROM payroll_processing WHERE id=${id};")" "^CLOSED$"
assert_match "close twice invalid" "$(run_cobol "PRL_CLOSE|${id}|x||||admin@test.com")" "ERROR\|INVALID_STATE"

# Audit + auth.
assert_match "audit rows" "$(db_query "SELECT COUNT(*) FROM payroll_audit WHERE batch_id=${id};")" "^[1-9]"
assert_match "non-admin refused" "$(run_cobol "PRL_VALIDATE|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

# Cleanup.
db_exec "DELETE FROM payroll_payment WHERE batch_id=${id};"
db_exec "DELETE FROM payroll_item WHERE batch_id=${id};"
db_exec "DELETE FROM payroll_employee WHERE batch_id=${id};"
db_exec "DELETE FROM payroll_audit WHERE batch_id=${id};"
db_exec "DELETE FROM payroll_processing WHERE id=${id};"
db_exec "DELETE FROM tax_audit WHERE detail LIKE 'PAY-D%';"
db_exec "DELETE FROM tax_management WHERE tax_ref IN ('TXR-PD');"
db_exec "DELETE FROM customer WHERE customer_ref='CUST-PAYD';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
