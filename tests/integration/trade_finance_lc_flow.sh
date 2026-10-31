#!/usr/bin/env bash
# Integration: Trade Finance LC -> customer -> document -> drawing -> GL -> settle.
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
db_exec "DELETE FROM customer WHERE customer_ref='CUST-LCINT';"
db_exec "INSERT INTO customer (customer_ref, full_name, customer_type, credit_limit, used_credit, status, kyc_status, created_by) VALUES ('CUST-LCINT','PT Int','CORPORATE',2000000,0,'ONBOARDED','APPROVED','admin@test.com');"
ADMIN="lcint@test.com"
db_exec "INSERT INTO users (email, password_hash, full_name, dob, status, role) VALUES ('$ADMIN', CONCAT('SHA256_',SHA2('secret123',256)), 'LC Int', '1990-01-01', 'VERIFIED', 'SUPER_ADMIN') ON DUPLICATE KEY UPDATE role='SUPER_ADMIN', status='VERIFIED';"

echo "=== Trade Finance LC integration ==="

OUT=$(run_cobol "LOC_CREATE|LC-INT-1|CUST-LCINT|PT Buyer|SIGHT|IDR:1000000:2026-12-31|$ADMIN")
assert_match "create draft" "$OUT" "SUCCESS\|LOC_CREATE"
LC_ID=$(printf '%s' "$OUT" | awk -F'|' '{print $3}')

assert_match "submit" "$(run_cobol "LOC_SUBMIT|${LC_ID}|||||$ADMIN")" "SUCCESS\|LOC_SUBMIT"
assert_match "approve" "$(run_cobol "LOC_APPROVE|${LC_ID}|||||$ADMIN")" "SUCCESS\|LOC_APPROVE"
assert_match "issue" "$(run_cobol "LOC_ISSUE|${LC_ID}|||||$ADMIN")" "SUCCESS\|LOC_ISSUE"

# Amendment: +100k, expiry extended.
assert_match "amend" "$(run_cobol "LOC_AMEND|${LC_ID}|100000|2027-01-31|Extend||||$ADMIN")" "SUCCESS\|LOC_AMEND"
assert_match "amended amount" "$(db_query "SELECT lc_amount FROM letter_of_credit WHERE id=${LC_ID};")" "^1100000"
assert_match "amended expiry" "$(db_query "SELECT expiry_date FROM letter_of_credit WHERE id=${LC_ID};")" "^2027-01-31$"

assert_match "document" "$(run_cobol "LOC_DOCUMENT|${LC_ID}|INVOICE|DOC-1|ACCEPTED||$ADMIN")" "SUCCESS\|LOC_DOCUMENT"
assert_match "draw" "$(run_cobol "LOC_DRAW|${LC_ID}|1|300000|IDR|2027-01-15|$ADMIN")" "SUCCESS\|LOC_DRAW"
DID=$(db_query "SELECT drawing_id FROM lc_drawing WHERE lc_id=${LC_ID} ORDER BY drawing_id DESC LIMIT 1;")

# GL: settle 300k (debit customer deposits 1100, credit cash 1000).
GL_OUT=$(run_cobol "GL_JOURNAL_POST|2026-10-30|LC settlement ${LC_ID}|1100|1000|IDR:300000|$ADMIN")
assert_match "gl posted" "$GL_OUT" "SUCCESS\|GL_POSTED"
GJID=$(db_query "SELECT id FROM gl_journal ORDER BY id DESC LIMIT 1;")
assert_match "gl balanced" "$(db_query "SELECT IF(SUM(debit_amount)=SUM(credit_amount) AND SUM(debit_amount)>0,'BALANCED','UNBALANCED') FROM gl_journal_line WHERE journal_id=${GJID};")" "^BALANCED$"

assert_match "settle" "$(run_cobol "LOC_SETTLE|${DID}|300000|${GJID}|PMC-INT-1||$ADMIN")" "SUCCESS\|LOC_SETTLE"
assert_match "drawing settled" "$(db_query "SELECT status FROM lc_drawing WHERE drawing_id=${DID};")" "^SETTLED$"
assert_match "lc settled" "$(db_query "SELECT status FROM letter_of_credit WHERE id=${LC_ID};")" "^SETTLED$"
assert_match "gl link" "$(db_query "SELECT gl_journal_id FROM lc_settlement WHERE drawing_id=${DID};")" "^${GJID}$"

assert_match "close" "$(run_cobol "LOC_CLOSE|${LC_ID}|Selesai||||$ADMIN")" "SUCCESS\|LOC_CLOSE"
assert_match "closed" "$(db_query "SELECT status FROM letter_of_credit WHERE id=${LC_ID};")" "^CLOSED$"

# Cleanup.
db_exec "DELETE FROM letter_of_credit WHERE lc_ref='LC-INT-1';"
db_exec "DELETE FROM customer WHERE customer_ref='CUST-LCINT';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
