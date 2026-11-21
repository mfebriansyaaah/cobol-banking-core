#!/usr/bin/env bash
# arch9 P0 regression suite (WP-02): one place that re-proves the five
# WP-02 correctness fixes. Each section mirrors the dedicated suite but
# asserts only the regression that WP-02 introduced:
#   1. CHECK_TOKEN compares the full version (no prefix match at ver=10).
#   2. Empty/unknown COBOL output never maps to success (gateway unit tests;
#      listed here as documentation, enforced in middleware/test/result.test.js).
#   3. Dashboard denial audit uses status FAILED (valid enum).
#   4. LOAN_APPROVE/REJECT are fail-closed (AFFECTED_1) and audited.
#   5. TRANSFER re-reads account status under lock and guards postings.
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
A="admin@test.com"
U="p0a@test.com"
V="p0b@test.com"
for E in "$U" "$V"; do
db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='${E}'));"
db_exec "DELETE FROM pending_transactions WHERE from_email='${E}' OR to_email='${E}';"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='${E}');"
db_exec "DELETE FROM loan_audit WHERE loan_id IN (SELECT id FROM loan_application WHERE customer_email='${E}');"
db_exec "DELETE FROM loan_application WHERE customer_email='${E}';"
db_exec "DELETE FROM users WHERE email='${E}';"
run_cobol "REQUEST_SIGNUP|${E}|Passw0rd!|P Zero|1990-01-01" >/dev/null
code="$(db_query "SELECT code FROM verification_logs WHERE email='${E}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run_cobol "VERIFY_EMAIL|${E}|${code}" >/dev/null
done
db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 1000.00 FROM users WHERE email='${U}';"
db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 1000.00 FROM users WHERE email='${V}';"

# 1. Full version comparison (WP-02 T-02.1).
db_exec "UPDATE users SET token_version = 10 WHERE email='${U}';"
assert_match "p0 old ver=1 refused at DB ver=10" "$(run_cobol "CHECK_TOKEN|${U}|1||||")" "ERROR\|TOKEN_REVOKED"
assert_match "p0 ver=10 accepted" "$(run_cobol "CHECK_TOKEN|${U}|10||||")" "SUCCESS\|TOKEN_VALID"
db_exec "UPDATE users SET token_version = 1 WHERE email='${U}';"

# 3. Dashboard denial audit (WP-02 T-02.3).
denied_before="$(db_query "SELECT COUNT(*) FROM audit_trail WHERE action='AUTHZ_DENIED' AND entity_type='DASHBOARD' AND status='FAILED';")"
assert_match "p0 non-admin dashboard refused" "$(run_cobol "DSH_OVERVIEW||||||${U}")" "ERROR\|FORBIDDEN"
denied_after="$(db_query "SELECT COUNT(*) FROM audit_trail WHERE action='AUTHZ_DENIED' AND entity_type='DASHBOARD' AND status='FAILED';")"
if [ "$denied_after" -gt "$denied_before" ] 2>/dev/null; then denied_grew=yes; else denied_grew=no; fi
assert_match "p0 denied dashboard audit recorded" "$denied_grew" "^yes$"

# 4. Loan approve/reject fail-closed + audited (WP-02 T-02.4).
apply_out="$(run_cobol "LOAN_APPLY|${U}|5000.00|USD|12|5.0|${A}")"
assert_match "p0 loan apply ok" "$apply_out" "SUCCESS\|LOAN_APPLY\|[0-9]+"
app_id="$(printf '%s' "$apply_out" | awk -F'|' '{print $3}')"
assert_match "p0 loan approve ok" "$(run_cobol "LOAN_APPROVE|${app_id}|5.0|ok|||${A}")" "SUCCESS\|LOAN_APPROVE"
assert_match "p0 approve twice refused" "$(run_cobol "LOAN_APPROVE|${app_id}|5.0|again|||${A}")" "ERROR\|INVALID_STATUS"
assert_match "p0 reject approved refused" "$(run_cobol "LOAN_REJECT|${app_id}|late||||${A}")" "ERROR\|INVALID_STATUS"
assert_match "p0 approve audit recorded" "$(db_query "SELECT COUNT(*) FROM loan_audit WHERE loan_id=${app_id} AND action='LOAN_APPROVE';")" "^[1-9]"

# 5. Transfer status re-check under lock (WP-02 T-02.5).
assert_match "p0 transfer ok" "$(run_cobol "TRANSFER|${U}|${V}|10.00|P0T-1|||")" "SUCCESS\|TRANSFER_OK"
db_exec "UPDATE accounts SET status='FROZEN' WHERE user_id=(SELECT id FROM users WHERE email='${V}') AND currency_id=1;"
assert_match "p0 frozen target refused" "$(run_cobol "TRANSFER|${U}|${V}|10.00|P0T-2|||")" "ERROR\|ACCOUNT_FROZEN"
db_exec "UPDATE accounts SET status='CLOSED' WHERE user_id=(SELECT id FROM users WHERE email='${V}') AND currency_id=1;"
assert_match "p0 closed target refused" "$(run_cobol "TRANSFER|${U}|${V}|10.00|P0T-3|||")" "ERROR\|ACCOUNT_CLOSED"
db_exec "UPDATE accounts SET status='ACTIVE' WHERE user_id=(SELECT id FROM users WHERE email='${V}') AND currency_id=1;"

db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${U}','${V}')));"
db_exec "DELETE FROM pending_transactions WHERE from_email IN ('${U}','${V}') OR to_email IN ('${U}','${V}');"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${U}','${V}'));"
db_exec "DELETE FROM loan_audit WHERE loan_id IN (SELECT id FROM loan_application WHERE customer_email IN ('${U}','${V}'));"
db_exec "DELETE FROM loan_application WHERE customer_email IN ('${U}','${V}');"
db_exec "DELETE FROM users WHERE email IN ('${U}','${V}');"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
