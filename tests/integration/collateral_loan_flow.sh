#!/usr/bin/env bash
# Integration: loan -> collateral -> release.
# Proves collateral domain is continuous with loan core.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
if ! db_available; then echo "SKIP: DB unavailable"; exit 0; fi

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

db_seed
db_reset_collateral

ADMIN="collab-int@test.com"
db_exec "INSERT INTO users (email, password_hash, full_name, dob, status, role) VALUES ('$ADMIN', CONCAT('SHA256_',SHA2('secret123',256)), 'CollabInt', '1990-01-01', 'VERIFIED', 'SUPER_ADMIN') ON DUPLICATE KEY UPDATE role='SUPER_ADMIN', status='VERIFIED';"
db_exec "INSERT INTO loan_application (customer_email, principal, currency, term_months, interest_rate, status, created_by) VALUES ('$ADMIN', 1000000, 'IDR', 12, 5.0000, 'DISBURSED', '$ADMIN');"
LOAN_ID=$(db_query "SELECT id FROM loan_application WHERE customer_email='$ADMIN' ORDER BY id DESC LIMIT 1;")

echo "=== Collateral <-> Loan integration (loan $LOAN_ID) ==="

REG=$(run_cobol "CLT_REGISTER|CLT-INT-1|Ruko Sudirman|PROPERTY|800000000|$ADMIN|$ADMIN")
assert_match "register" "$REG" "SUCCESS\|CLT_REGISTER"
CID=$(printf '%s' "$REG" | awk -F'|' '{print $3}')

assert_match "appraise" "$(run_cobol "CLT_APPRAISE|${CID}|750000000|KJPP|MARKET|Appraisal|$ADMIN")" "SUCCESS\|CLT_APPRAISE"
assert_match "pledge" "$(run_cobol "CLT_PLEDGE|${CID}|${LOAN_ID}|500000000|10||$ADMIN")" "SUCCESS\|CLT_PLEDGE"
assert_match "status pledged" "$(db_query "SELECT status FROM collateral WHERE id=${CID};")" "^PLEDGED$"

# Over-pledge must be rejected (limit = 750jt * 0.9 = 675jt, already 500jt pledged)
assert_match "over-pledge rejected" "$(run_cobol "CLT_PLEDGE|${CID}|${LOAN_ID}|200000000|10||$ADMIN")" "ERROR\|LIMIT"

assert_match "release" "$(run_cobol "CLT_RELEASE|${CID}|Lunas||||$ADMIN")" "SUCCESS\|CLT_RELEASE"
assert_match "status released" "$(db_query "SELECT status FROM collateral WHERE id=${CID};")" "^RELEASED$"

# GL-linked dispose path: second collateral -> repossess -> GL post -> dispose with link.
REG2=$(run_cobol "CLT_REGISTER|CLT-INT-2|Gudang Bekasi|WAREHOUSE|300000000|$ADMIN|$ADMIN")
CID2=$(printf '%s' "$REG2" | awk -F'|' '{print $3}')
run_cobol "CLT_APPRAISE|${CID2}|280000000|KJPP|MARKET|Awal|$ADMIN" >/dev/null
run_cobol "CLT_PLEDGE|${CID2}|${LOAN_ID}|100000000|10||$ADMIN" >/dev/null
run_cobol "CLT_REPOSSESS|${CID2}|${LOAN_ID}|Default|||$ADMIN" >/dev/null
GL_OUT=$(run_cobol "GL_JOURNAL_POST|2026-10-29|Disposal ${CID2}|1000|4210|IDR:120000000|$ADMIN")
assert_match "gl posted" "$GL_OUT" "SUCCESS\|GL_POSTED"
JID=$(db_query "SELECT id FROM gl_journal ORDER BY id DESC LIMIT 1;")
assert_match "dispose with gl" "$(run_cobol "CLT_DISPOSE|${CID2}|120000000|Lelang|${JID}||$ADMIN")" "SUCCESS\|CLT_DISPOSE"
assert_match "gl linked" "$(db_query "SELECT gl_journal_id FROM collateral WHERE id=${CID2};")" "^${JID}$"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
