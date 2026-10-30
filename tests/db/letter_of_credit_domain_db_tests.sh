#!/usr/bin/env bash
# Trade Finance — Letter of Credit lifecycle (PR-202).
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
db_reset_letter_of_credit
db_exec "DELETE FROM customer WHERE customer_ref IN ('CUST-LCT','CUST-LCT2');"
db_exec "INSERT INTO customer (customer_ref, full_name, customer_type, credit_limit, used_credit, status, kyc_status, created_by) VALUES ('CUST-LCT','PT Applicant','CORPORATE',1000000,0,'ONBOARDED','APPROVED','admin@test.com');"

# CREATE draft.
out="$(run_cobol "LOC_CREATE|LCT-1|CUST-LCT|PT Buyer|SIGHT|IDR:1000000:2026-12-31|admin@test.com")"
assert_match "create ok" "$out" "SUCCESS\|LOC_CREATE\|[0-9]+"
id="$(printf '%s' "$out" | awk -F'|' '{print $3}')"
assert_match "status draft" "$(db_query "SELECT status FROM letter_of_credit WHERE id=${id};")" "^DRAFT$"
assert_match "amount parsed" "$(db_query "SELECT lc_amount FROM letter_of_credit WHERE id=${id};")" "^1000000"
assert_match "customer linked" "$(db_query "SELECT applicant_customer_ref FROM letter_of_credit WHERE id=${id};")" "^CUST-LCT$"

# Duplicate + unknown customer.
assert_match "duplicate ref" "$(run_cobol "LOC_CREATE|LCT-1|CUST-LCT|PT Buyer|SIGHT|IDR:1:2026-12-31|admin@test.com")" "ERROR\|DUPLICATE"
assert_match "unknown customer" "$(run_cobol "LOC_CREATE|LCT-X|CUST-NONE|PT Buyer|SIGHT|IDR:1:2026-12-31|admin@test.com")" "ERROR\|NOT_FOUND"

# SUBMIT -> APPROVE -> ISSUE.
assert_match "submit" "$(run_cobol "LOC_SUBMIT|${id}|||||admin@test.com")" "SUCCESS\|LOC_SUBMIT"
assert_match "submit twice invalid" "$(run_cobol "LOC_SUBMIT|${id}|||||admin@test.com")" "ERROR\|INVALID_STATE"
assert_match "approve" "$(run_cobol "LOC_APPROVE|${id}|||||admin@test.com")" "SUCCESS\|LOC_APPROVE"
assert_match "issue" "$(run_cobol "LOC_ISSUE|${id}|321||||admin@test.com")" "SUCCESS\|LOC_ISSUE"
assert_match "issued persisted" "$(db_query "SELECT status FROM letter_of_credit WHERE id=${id};")" "^ISSUED$"
assert_match "gl linked" "$(db_query "SELECT gl_journal_id FROM letter_of_credit WHERE id=${id};")" "^321$"

# DRAW requires accepted document.
assert_match "draw requires doc" "$(run_cobol "LOC_DRAW|${id}|1|200000|IDR|2026-12-01|admin@test.com")" "ERROR\|DOCUMENT_REQUIRED"
assert_match "document accepted" "$(run_cobol "LOC_DOCUMENT|${id}|INVOICE|DOC-1|ACCEPTED||admin@test.com")" "SUCCESS\|LOC_DOCUMENT"
assert_match "draw" "$(run_cobol "LOC_DRAW|${id}|1|200000|IDR|2026-12-01|admin@test.com")" "SUCCESS\|LOC_DRAW"
assert_match "drawn persisted" "$(db_query "SELECT drawn_amount FROM letter_of_credit WHERE id=${id};")" "^200000"
assert_match "over-draw limit" "$(run_cobol "LOC_DRAW|${id}|2|900000|IDR|2026-12-01|admin@test.com")" "ERROR\|LIMIT"

# SETTLE.
did="$(db_query "SELECT drawing_id FROM lc_drawing WHERE lc_id=${id} ORDER BY drawing_id DESC LIMIT 1;")"
assert_match "settle" "$(run_cobol "LOC_SETTLE|${did}|200000|322|PMC-1||admin@test.com")" "SUCCESS\|LOC_SETTLE"
assert_match "drawing settled" "$(db_query "SELECT status FROM lc_drawing WHERE drawing_id=${did};")" "^SETTLED$"
assert_match "lc settled" "$(db_query "SELECT status FROM letter_of_credit WHERE id=${id};")" "^SETTLED$"
assert_match "settlement row" "$(db_query "SELECT COUNT(*) FROM lc_settlement WHERE drawing_id=${did} AND status='SETTLED';")" "^1$"

# CLOSE.
assert_match "close" "$(run_cobol "LOC_CLOSE|${id}|Selesai||||admin@test.com")" "SUCCESS\|LOC_CLOSE"
assert_match "closed persisted" "$(db_query "SELECT status FROM letter_of_credit WHERE id=${id};")" "^CLOSED$"

# Limit rejection: LC > customer credit_limit.
out2="$(run_cobol "LOC_CREATE|LCT-2|CUST-LCT|PT Buyer 2|USANCE|IDR:2000000:2026-12-31|admin@test.com")"
id2="$(printf '%s' "$out2" | awk -F'|' '{print $3}')"
run_cobol "LOC_SUBMIT|${id2}|||||admin@test.com" >/dev/null
assert_match "approve over limit" "$(run_cobol "LOC_APPROVE|${id2}|||||admin@test.com")" "ERROR\|LIMIT"

# Audit rows exist.
assert_match "audit rows" "$(db_query "SELECT COUNT(*) FROM letter_of_credit_audit WHERE letter_of_credit_id=${id};")" "^[1-9]"

# Cleanup.
db_exec "DELETE FROM letter_of_credit WHERE lc_ref LIKE 'LCT-%';"
db_exec "DELETE FROM customer WHERE customer_ref IN ('CUST-LCT','CUST-LCT2');"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
