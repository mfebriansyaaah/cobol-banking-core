#!/usr/bin/env bash
# Payroll schema/constraint tests (PR-601).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
require_db

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

# Batch header with owner/period/account/totals.
db_exec "DELETE FROM payroll_processing WHERE payroll_ref='PAY-S1';"
db_exec "INSERT INTO payroll_processing (payroll_ref, company_customer_ref, batch_name, payroll_type, period_start, period_end, currency, source_account_id, status, created_by) VALUES ('PAY-S1','CUST-1','Gaji Okt','MONTHLY','2026-10-01','2026-10-31','IDR',1,'DRAFT','admin@test.com');"
BID="$(db_query "SELECT id FROM payroll_processing WHERE payroll_ref='PAY-S1';")"
assert_match "batch inserted" "$BID" "^[0-9]+$"
assert_match "status draft" "$(db_query "SELECT status FROM payroll_processing WHERE id=${BID};")" "^DRAFT$"

# Employee unique per batch + non-negative amounts.
db_exec "INSERT INTO payroll_employee (batch_id, employee_ref, employee_name, employee_account_id, gross_amount, tax_amount, deduction_amount, net_amount) VALUES (${BID}, 'EMP-1', 'Budi', 2, 10000000, 500000, 0, 9500000);"
assert_match "employee row" "$(db_query "SELECT COUNT(*) FROM payroll_employee WHERE batch_id=${BID};")" "^1$"
db_exec "INSERT INTO payroll_employee (batch_id, employee_ref, employee_name, gross_amount) VALUES (${BID}, 'EMP-1', 'X', 1);" 2>/dev/null
assert_match "employee unique" "$(db_query "SELECT COUNT(*) FROM payroll_employee WHERE batch_id=${BID};")" "^1$"
db_exec "INSERT INTO payroll_employee (batch_id, employee_ref, employee_name, gross_amount, tax_amount) VALUES (${BID}, 'EMP-NEG', 'X', 1, -1);" 2>/dev/null
assert_match "tax non-negative" "$(db_query "SELECT COUNT(*) FROM payroll_employee WHERE employee_ref='EMP-NEG';")" "^0$"

# Item linked to batch + employee.
EID="$(db_query "SELECT employee_id FROM payroll_employee WHERE batch_id=${BID} AND employee_ref='EMP-1';")"
db_exec "INSERT INTO payroll_item (batch_id, employee_id, item_type, amount, detail) VALUES (${BID}, ${EID}, 'SALARY', 10000000, 'gaji pokok');"
assert_match "item row" "$(db_query "SELECT COUNT(*) FROM payroll_item WHERE batch_id=${BID};")" "^1$"

# Payment row pending by default.
db_exec "INSERT INTO payroll_payment (batch_id, employee_id, amount) VALUES (${BID}, ${EID}, 9500000);"
assert_match "payment row" "$(db_query "SELECT status FROM payroll_payment WHERE batch_id=${BID} AND employee_id=${EID};")" "^PENDING$"

# Cleanup (children first).
db_exec "DELETE FROM payroll_payment WHERE batch_id=${BID};"
db_exec "DELETE FROM payroll_item WHERE batch_id=${BID};"
db_exec "DELETE FROM payroll_employee WHERE batch_id=${BID};"
db_exec "DELETE FROM payroll_audit WHERE batch_id=${BID};"
db_exec "DELETE FROM payroll_processing WHERE id=${BID};"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
