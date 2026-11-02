#!/usr/bin/env bash
# Tax Withholding calculation + GL + reversal (PR-402).
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
db_exec "DELETE FROM customer WHERE customer_ref='CUST-TXD';"
db_exec "INSERT INTO customer (customer_ref, full_name, customer_type, credit_limit, used_credit, status, kyc_status, created_by) VALUES ('CUST-TXD','PT D','CORPORATE',1000000,0,'ONBOARDED','APPROVED','admin@test.com');"

# Rule create: 5% + 0 fixed, threshold 50k, cap 1jt.
out="$(run_cobol "TXM_RULE_CREATE|TXR-D1|PPh 21|WITHHOLDING|5:0:50000:1000000|IDR:5000:2026-01-01:|admin@test.com")"
assert_match "rule create" "$out" "SUCCESS\|TXM_RULE_CREATE\|[0-9]+"
rid="$(printf '%s' "$out" | awk -F'|' '{print $3}')"
assert_match "rate stored" "$(db_query "SELECT rate_pct FROM tax_management WHERE id=${rid};")" "^5.0000$"
assert_match "duplicate rule" "$(run_cobol "TXM_RULE_CREATE|TXR-D1|PPh 21|WITHHOLDING|5:0:50000:1000000|IDR:5000:2026-01-01:|admin@test.com")" "ERROR\|DUPLICATE"
assert_match "bad rate" "$(run_cobol "TXM_RULE_CREATE|TXR-X|X|WITHHOLDING|101:0:0:0|IDR:5000:2026-01-01:|admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "rule get" "$(run_cobol "TXM_RULE_GET|${rid}|||||admin@test.com")" "SUCCESS\|TXM_RULE_GET"
assert_match "rule list" "$(run_cobol "TXM_RULE_LIST|||50|0||admin@test.com")" "TXR-D1"

# Rule update rate 5 -> 10.
assert_match "rule update" "$(run_cobol "TXM_RULE_UPDATE|${rid}|10:0:50000:1000000||||admin@test.com")" "SUCCESS\|TXM_RULE_UPDATE"
assert_match "rate updated" "$(db_query "SELECT rate_pct FROM tax_management WHERE id=${rid};")" "^10.0000$"

# CALC: 1jt base at 10% = 100rb.
out2="$(run_cobol "TXM_CALC|${rid}|FEE|FEE-D1|1000000|IDR|admin@test.com")"
assert_match "calc" "$out2" "SUCCESS\|TXM_CALC\|[0-9]+\|100000"
eid="$(printf '%s' "$out2" | awk -F'|' '{print $3}')"
assert_match "entry calculated" "$(db_query "SELECT status FROM tax_withholding_entry WHERE entry_id=${eid};")" "^CALCULATED$"
assert_match "duplicate source" "$(run_cobol "TXM_CALC|${rid}|FEE|FEE-D1|1000000|IDR|admin@test.com")" "ERROR\|DUPLICATE"

# Below threshold (40rb < 50rb) -> tax 0.
out3="$(run_cobol "TXM_CALC|${rid}|FEE|FEE-D2|40000|IDR|admin@test.com")"
assert_match "below threshold zero" "$out3" "SUCCESS\|TXM_CALC\|[0-9]+\|0"
eid0="$(printf '%s' "$out3" | awk -F'|' '{print $3}')"
assert_match "zero persisted" "$(db_query "SELECT tax_amount FROM tax_withholding_entry WHERE entry_id=${eid0};")" "^0"

# Negative / zero / unknown rule.
assert_match "negative base" "$(run_cobol "TXM_CALC|${rid}|FEE|FEE-N1|-5|IDR|admin@test.com")" "ERROR\|INVALID_AMOUNT"
assert_match "unknown rule" "$(run_cobol "TXM_CALC|999999|FEE|FEE-N2|100|IDR|admin@test.com")" "ERROR\|NOT_FOUND"

# Max cap: isolated rule 50% cap 100.
out4="$(run_cobol "TXM_RULE_CREATE|TXR-DCAP|Cap|WITHHOLDING|50:0:0:100|IDR:5000:2026-01-01:|admin@test.com")"
rid2="$(printf '%s' "$out4" | awk -F'|' '{print $3}')"
out5="$(run_cobol "TXM_CALC|${rid2}|FEE|FEE-CAP|1000000|IDR|admin@test.com")"
assert_match "max cap" "$out5" "SUCCESS\|TXM_CALC\|[0-9]+\|100"

# POST + double post + REVERSE + double reverse.
assert_match "post" "$(run_cobol "TXM_POST|${eid}|777||||admin@test.com")" "SUCCESS\|TXM_POST"
assert_match "posted persisted" "$(db_query "SELECT status FROM tax_withholding_entry WHERE entry_id=${eid};")" "^POSTED$"
assert_match "gl linked" "$(db_query "SELECT gl_journal_id FROM tax_withholding_entry WHERE entry_id=${eid};")" "^777$"
assert_match "double post" "$(run_cobol "TXM_POST|${eid}|||||admin@test.com")" "ERROR\|INVALID_STATE"
assert_match "reverse" "$(run_cobol "TXM_REVERSE|${eid}|koreksi||||admin@test.com")" "SUCCESS\|TXM_REVERSE"
assert_match "reversed persisted" "$(db_query "SELECT status FROM tax_withholding_entry WHERE entry_id=${eid};")" "^REVERSED$"
assert_match "double reverse" "$(run_cobol "TXM_REVERSE|${eid}|x||||admin@test.com")" "ERROR\|INVALID_STATE"
assert_match "reverse draft invalid" "$(run_cobol "TXM_REVERSE|${eid0}|x||||admin@test.com")" "ERROR\|INVALID_STATE"

assert_match "audit rows" "$(db_query "SELECT COUNT(*) FROM tax_audit WHERE entry_id=${eid} OR rule_id=${rid};")" "^[1-9]"
assert_match "non-admin refused" "$(run_cobol "TXM_CALC|${rid}|FEE|FEE-Z|100|IDR|sender@test.com")" "ERROR\|FORBIDDEN"

# Cleanup.
db_exec "DELETE FROM tax_withholding_entry WHERE source_ref LIKE 'FEE-D%' OR source_ref='FEE-CAP';"
db_exec "DELETE FROM tax_audit WHERE detail LIKE 'FEE-%' OR detail LIKE 'TXR-D%';"
db_exec "DELETE FROM tax_management WHERE tax_ref LIKE 'TXR-D%';"
db_exec "DELETE FROM customer WHERE customer_ref='CUST-TXD';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
