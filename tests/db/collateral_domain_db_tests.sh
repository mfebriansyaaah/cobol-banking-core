#!/usr/bin/env bash
# Collateral Management domain (PR-102) end-to-end DB tests.
# Covers REGISTER -> APPRAISE -> REVALUE -> PLEDGE -> ALLOCATE -> RELEASE
# and REPOSSESS -> DISPOSE, plus failure paths.
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
db_reset_collateral

# Self-contained disbursed loan (do not rely on other suites' leftovers;
# CI runs on a fresh DB where loan_application may be empty).
db_exec "DELETE FROM loan_application WHERE customer_email='collat@test.com';"
db_exec "INSERT INTO loan_application (customer_email, principal, currency, term_months, interest_rate, status, created_by) VALUES ('collat@test.com', 1000000, 'IDR', 12, 5.0000, 'DISBURSED', 'admin@test.com');"
LOAN_ID="$(db_query "SELECT id FROM loan_application WHERE customer_email='collat@test.com' ORDER BY id DESC LIMIT 1;")"

# REGISTER happy path.
reg_out="$(run_cobol "CLT_REGISTER|CLT-DOM-1|Rumah Jakarta|PROPERTY|500000000|CUST-001|admin@test.com")"
assert_match "REGISTER ok" "$reg_out" "SUCCESS\|CLT_REGISTER\|[0-9]+"
cid="$(printf '%s' "$reg_out" | awk -F'|' '{print $3}')"
assert_match "status registered" "$(db_query "SELECT status FROM collateral WHERE id=${cid};")" "^REGISTERED$"
assert_match "customer stored" "$(db_query "SELECT customer_ref FROM collateral WHERE id=${cid};")" "CUST-001"

# REGISTER duplicate rejected.
assert_match "duplicate ref" "$(run_cobol "CLT_REGISTER|CLT-DOM-1|Other|PROPERTY|100|CUST-001|admin@test.com")" "ERROR\|DUPLICATE"

# REGISTER invalid amount.
assert_match "invalid amount" "$(run_cobol "CLT_REGISTER|CLT-DOM-X|Rumah|PROPERTY|0|CUST-001|admin@test.com")" "ERROR\|INVALID_AMOUNT"

# APPRAISE happy path.
assert_match "APPRAISE ok" "$(run_cobol "CLT_APPRAISE|${cid}|450000000|Budi|MARKET|Awal|admin@test.com")" "SUCCESS\|CLT_APPRAISE"
assert_match "status appraised" "$(db_query "SELECT status FROM collateral WHERE id=${cid};")" "^APPRAISED$"
assert_match "valuation row" "$(db_query "SELECT COUNT(*) FROM collateral_valuation WHERE collateral_id=${cid};")" "^1$"

# APPRAISE twice rejected (must use REVALUE).
assert_match "appraise twice invalid state" "$(run_cobol "CLT_APPRAISE|${cid}|460000000|Budi|MARKET|Ulang|admin@test.com")" "ERROR\|INVALID_STATE"

# REVALUE happy path.
assert_match "REVALUE ok" "$(run_cobol "CLT_REVALUE|${cid}|480000000|Budi|MARKET|Naik|admin@test.com")" "SUCCESS\|CLT_REVALUE"
assert_match "revalue persisted" "$(db_query "SELECT appraised_value FROM collateral WHERE id=${cid};")" "^480000000"

# PLEDGE happy path (haircut 10% -> limit 432000000).
pledge_out="$(run_cobol "CLT_PLEDGE|${cid}|${LOAN_ID}|200000000|10||admin@test.com")"
assert_match "PLEDGE ok" "$pledge_out" "SUCCESS\|CLT_PLEDGE\|[0-9]+"
pid="$(printf '%s' "$pledge_out" | awk -F'|' '{print $3}')"
assert_match "status pledged" "$(db_query "SELECT status FROM collateral WHERE id=${cid};")" "^PLEDGED$"

# PLEDGE over limit rejected.
assert_match "over-pledge limit" "$(run_cobol "CLT_PLEDGE|${cid}|${LOAN_ID}|500000000|10||admin@test.com")" "ERROR\|LIMIT"

# PLEDGE unknown loan rejected.
assert_match "unknown loan" "$(run_cobol "CLT_PLEDGE|${cid}|999999999|10000|10||admin@test.com")" "ERROR\|NOT_FOUND"

# ALLOCATE happy path.
assert_match "ALLOCATE ok" "$(run_cobol "CLT_ALLOCATE|${pid}|${LOAN_ID}|150000000|||admin@test.com")" "SUCCESS\|CLT_ALLOCATE"

# ALLOCATE over pledge rejected.
assert_match "over-allocate limit" "$(run_cobol "CLT_ALLOCATE|${pid}|${LOAN_ID}|100000000|||admin@test.com")" "ERROR\|LIMIT"

# RELEASE blocked while loan open, then ok after loan closed.
assert_match "release blocked open loan" "$(run_cobol "CLT_RELEASE|${cid}|Lunas||||admin@test.com")" "ERROR\|INVALID_STATE"
db_exec "UPDATE loan_application SET status='CLOSED' WHERE id=${LOAN_ID};"
assert_match "RELEASE ok" "$(run_cobol "CLT_RELEASE|${cid}|Lunas||||admin@test.com")" "SUCCESS\|CLT_RELEASE"
assert_match "released persisted" "$(db_query "SELECT status FROM collateral WHERE id=${cid};")" "^RELEASED$"
db_exec "UPDATE loan_application SET status='DISBURSED' WHERE id=${LOAN_ID};"

# Second collateral for repossess/dispose.
reg2="$(run_cobol "CLT_REGISTER|CLT-DOM-2|Mobil Avanza|VEHICLE|200000000|CUST-002|admin@test.com")"
cid2="$(printf '%s' "$reg2" | awk -F'|' '{print $3}')"
run_cobol "CLT_APPRAISE|${cid2}|180000000|Susi|MARKET|Awal|admin@test.com" >/dev/null
run_cobol "CLT_PLEDGE|${cid2}|${LOAN_ID}|100000000|10||admin@test.com" >/dev/null
assert_match "REPOSSESS ok" "$(run_cobol "CLT_REPOSSESS|${cid2}|${LOAN_ID}|Default 90 hari|||admin@test.com")" "SUCCESS\|CLT_REPOSSESS"
assert_match "repossessed persisted" "$(db_query "SELECT status FROM collateral WHERE id=${cid2};")" "^REPOSSESSED$"
assert_match "DISPOSE ok" "$(run_cobol "CLT_DISPOSE|${cid2}|150000000|Lelang|||admin@test.com")" "SUCCESS\|CLT_DISPOSE"
assert_match "disposed persisted" "$(db_query "SELECT status FROM collateral WHERE id=${cid2};")" "^DISPOSED$"

# Audit rows exist.
# GL linkage: post disposal journal then dispose second collateral with link.
gl_out="$(run_cobol "GL_JOURNAL_POST|2026-10-29|Disposal ${cid2}|1000|4210|IDR:150000000|admin@test.com")"
assert_match "GL posted" "$gl_out" "SUCCESS\|GL_POSTED"
gjid="$(db_query "SELECT id FROM gl_journal ORDER BY id DESC LIMIT 1;")"
# Re-create a fresh repossessed collateral to test GL link (cid2 already disposed).
reg3="$(run_cobol "CLT_REGISTER|CLT-DOM-3|Gudang Cikarang|WAREHOUSE|300000000|CUST-001|admin@test.com")"
cid3="$(printf '%s' "$reg3" | awk -F'|' '{print $3}')"
run_cobol "CLT_APPRAISE|${cid3}|280000000|KJPP|MARKET|Awal|admin@test.com" >/dev/null
run_cobol "CLT_PLEDGE|${cid3}|${LOAN_ID}|100000000|10||admin@test.com" >/dev/null
run_cobol "CLT_REPOSSESS|${cid3}|${LOAN_ID}|Default|||admin@test.com" >/dev/null
assert_match "DISPOSE with GL" "$(run_cobol "CLT_DISPOSE|${cid3}|150000000|Lelang|${gjid}||admin@test.com")" "SUCCESS\|CLT_DISPOSE"
assert_match "gl linked" "$(db_query "SELECT gl_journal_id FROM collateral WHERE id=${cid3};")" "^${gjid}$"
assert_match "journal balanced" "$(db_query "SELECT IF(SUM(debit_amount)=SUM(credit_amount) AND SUM(debit_amount)>0,'BALANCED','UNBALANCED') FROM gl_journal_line WHERE journal_id=${gjid};")" "^BALANCED$"

assert_match "audit rows" "$(db_query "SELECT COUNT(*) FROM collateral_audit WHERE collateral_id=${cid};")" "^[1-9]"

# Non-admin refused.
assert_match "non-admin refused" "$(run_cobol "CLT_REGISTER|CLT-DOM-X|Rumah|PROPERTY|100|CUST-001|sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
