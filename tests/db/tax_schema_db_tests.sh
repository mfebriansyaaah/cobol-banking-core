#!/usr/bin/env bash
# Tax Withholding schema/constraint tests (PR-401).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
require_db

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

# Rule with rate/threshold/max/currency/GL window.
db_exec "DELETE FROM tax_management WHERE tax_ref='TXR-S1';"
db_exec "INSERT INTO tax_management (tax_ref, rule_code, tax_name, tax_type, max_tax, rate_pct, fixed_amount, threshold_amount, currency, gl_account_code, effective_from, enabled, status, created_by) VALUES ('TXR-S1','PPH21','PPh 21','WITHHOLDING',1000000,5.0000,0,50000,'IDR','5000',CURRENT_DATE,TRUE,'ACTIVE','admin@test.com');"
RID="$(db_query "SELECT id FROM tax_management WHERE tax_ref='TXR-S1';")"
assert_match "rule inserted" "$RID" "^[0-9]+$"
assert_match "rate stored" "$(db_query "SELECT rate_pct FROM tax_management WHERE id=${RID};")" "^5.0000$"
db_exec "INSERT INTO tax_management (tax_ref, rule_code, tax_name, tax_type, status, created_by) VALUES ('TXR-DUP','PPH21','X','WITHHOLDING','OPEN','admin@test.com');" 2>/dev/null
assert_match "rule code unique" "$(db_query "SELECT COUNT(*) FROM tax_management WHERE rule_code='PPH21';")" "^1$"

# Entry: one active entry per source (idempotent sources).
db_exec "INSERT INTO tax_withholding_entry (source_type, source_ref, customer_ref, base_amount, tax_amount, currency, rule_id, status, created_by) VALUES ('FEE','FEE-S1','CUST-1',1000000,50000,'IDR',${RID},'CALCULATED','admin@test.com');"
assert_match "entry row" "$(db_query "SELECT COUNT(*) FROM tax_withholding_entry WHERE source_ref='FEE-S1';")" "^1$"
db_exec "INSERT INTO tax_withholding_entry (source_type, source_ref, base_amount, tax_amount, created_by) VALUES ('FEE','FEE-S1',1,0,'admin@test.com');" 2>/dev/null
assert_match "entry source unique" "$(db_query "SELECT COUNT(*) FROM tax_withholding_entry WHERE source_ref='FEE-S1';")" "^1$"
db_exec "INSERT INTO tax_withholding_entry (source_type, source_ref, base_amount, tax_amount, created_by) VALUES ('FEE','FEE-NEG',-1,0,'admin@test.com');" 2>/dev/null
assert_match "entry amount check" "$(db_query "SELECT COUNT(*) FROM tax_withholding_entry WHERE source_ref='FEE-NEG';")" "^0$"

# Report run: one row per period/type/currency.
db_exec "INSERT INTO tax_report_run (period, tax_type, total_base, total_tax, currency, status, created_by) VALUES ('2026-10','WITHHOLDING',1000000,50000,'IDR','DRAFT','admin@test.com');"
assert_match "report row" "$(db_query "SELECT COUNT(*) FROM tax_report_run WHERE period='2026-10';")" "^1$"
db_exec "INSERT INTO tax_report_run (period, tax_type, total_base, total_tax, currency, created_by) VALUES ('2026-10','WITHHOLDING',1,0,'IDR','admin@test.com');" 2>/dev/null
assert_match "report unique" "$(db_query "SELECT COUNT(*) FROM tax_report_run WHERE period='2026-10';")" "^1$"

# Cleanup.
db_exec "DELETE FROM tax_withholding_entry WHERE source_ref IN ('FEE-S1','FEE-NEG');"
db_exec "DELETE FROM tax_report_run WHERE period='2026-10';"
db_exec "DELETE FROM tax_management WHERE tax_ref IN ('TXR-S1','TXR-DUP');"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
