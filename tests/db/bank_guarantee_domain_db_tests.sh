#!/usr/bin/env bash
# Trade Finance — Bank Guarantee lifecycle (PR-204).
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
db_reset_bank_guarantee
db_exec "DELETE FROM customer WHERE customer_ref='CUST-BGD';"
db_exec "INSERT INTO customer (customer_ref, full_name, customer_type, credit_limit, used_credit, status, kyc_status, created_by) VALUES ('CUST-BGD','PT BG','CORPORATE',1000000,0,'ONBOARDED','APPROVED','admin@test.com');"

out="$(run_cobol "BKG_CREATE|BGD-1|CUST-BGD|PT Seller|PERFORMANCE|IDR:1000000:2026-12-31|admin@test.com")"
assert_match "create draft" "$out" "SUCCESS\|BKG_CREATE\|[0-9]+"
id="$(printf '%s' "$out" | awk -F'|' '{print $3}')"
assert_match "status draft" "$(db_query "SELECT status FROM bank_guarantee WHERE id=${id};")" "^DRAFT$"
assert_match "amount parsed" "$(db_query "SELECT guarantee_amount FROM bank_guarantee WHERE id=${id};")" "^1000000"
assert_match "customer linked" "$(db_query "SELECT applicant_customer_ref FROM bank_guarantee WHERE id=${id};")" "^CUST-BGD$"

assert_match "duplicate ref" "$(run_cobol "BKG_CREATE|BGD-1|CUST-BGD|PT Seller|PERFORMANCE|IDR:1:2026-12-31|admin@test.com")" "ERROR\|DUPLICATE"
assert_match "unknown customer" "$(run_cobol "BKG_CREATE|BGD-X|CUST-NONE|PT Seller|PERFORMANCE|IDR:1:2026-12-31|admin@test.com")" "ERROR\|NOT_FOUND"

assert_match "submit" "$(run_cobol "BKG_SUBMIT|${id}|||||admin@test.com")" "SUCCESS\|BKG_SUBMIT"
assert_match "submit twice invalid" "$(run_cobol "BKG_SUBMIT|${id}|||||admin@test.com")" "ERROR\|INVALID_STATE"
assert_match "approve" "$(run_cobol "BKG_APPROVE|${id}|||||admin@test.com")" "SUCCESS\|BKG_APPROVE"
assert_match "issue" "$(run_cobol "BKG_ISSUE|${id}|456||||admin@test.com")" "SUCCESS\|BKG_ISSUE"
assert_match "issued persisted" "$(db_query "SELECT status FROM bank_guarantee WHERE id=${id};")" "^ISSUED$"
assert_match "gl linked" "$(db_query "SELECT gl_journal_id FROM bank_guarantee WHERE id=${id};")" "^456$"

# Claim over guarantee rejected, then valid claim.
assert_match "claim over limit" "$(run_cobol "BKG_CLAIM|${id}|BGD-C0|2000000|||admin@test.com")" "ERROR\|LIMIT"
clm="$(run_cobol "BKG_CLAIM|${id}|BGD-C1|250000|||admin@test.com")"
assert_match "claim ok" "$clm" "SUCCESS\|BKG_CLAIM\|[0-9]+"
cid="$(printf '%s' "$clm" | awk -F'|' '{print $3}')"
assert_match "guarantee claimed" "$(db_query "SELECT status FROM bank_guarantee WHERE id=${id};")" "^CLAIMED$"

# Close blocked while claim open.
assert_match "close blocked claim" "$(run_cobol "BKG_CLOSE|${id}|Done||||admin@test.com")" "ERROR\|INVALID_STATE"

assert_match "settle" "$(run_cobol "BKG_SETTLE|${cid}|250000|457|||admin@test.com")" "SUCCESS\|BKG_SETTLE"
assert_match "claim settled" "$(db_query "SELECT status FROM bg_claim WHERE claim_id=${cid};")" "^SETTLED$"
assert_match "guarantee settled" "$(db_query "SELECT status FROM bank_guarantee WHERE id=${id};")" "^SETTLED$"
assert_match "claimed amount" "$(db_query "SELECT claimed_amount FROM bank_guarantee WHERE id=${id};")" "^250000"
assert_match "gl claim link" "$(db_query "SELECT gl_journal_id FROM bg_claim WHERE claim_id=${cid};")" "^457$"

assert_match "close" "$(run_cobol "BKG_CLOSE|${id}|Selesai||||admin@test.com")" "SUCCESS\|BKG_CLOSE"
assert_match "closed persisted" "$(db_query "SELECT status FROM bank_guarantee WHERE id=${id};")" "^CLOSED$"

# Limit rejection: BG > customer credit_limit.
out2="$(run_cobol "BKG_CREATE|BGD-2|CUST-BGD|PT Seller 2|PERFORMANCE|IDR:3000000:2026-12-31|admin@test.com")"
id2="$(printf '%s' "$out2" | awk -F'|' '{print $3}')"
run_cobol "BKG_SUBMIT|${id2}|||||admin@test.com" >/dev/null
assert_match "approve over limit" "$(run_cobol "BKG_APPROVE|${id2}|||||admin@test.com")" "ERROR\|LIMIT"

assert_match "audit rows" "$(db_query "SELECT COUNT(*) FROM bank_guarantee_audit WHERE bank_guarantee_id=${id};")" "^[1-9]"

db_exec "DELETE FROM bank_guarantee WHERE guarantee_ref LIKE 'BGD-%';"
db_exec "DELETE FROM customer WHERE customer_ref='CUST-BGD';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
