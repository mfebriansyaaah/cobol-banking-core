#!/usr/bin/env bash
# Unified payment limits (Fase 2, payments 10/10): one evaluation per
# transfer with documented priority env caps -> payment policy/profile ->
# velocity, and a single reason code. PAY_CHECK must mirror PAY_ENFORCE
# exactly; TRANSFER surfaces policy per-txn as LIMIT_EXCEEDED and every
# window limit (daily amount/count, velocity) as DAILY_LIMIT_EXCEEDED.
# File mode (COBOL_TEST_SERVE=0) so per-call env caps apply.
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

export COBOL_TEST_SERVE=0
db_seed
A="admin@test.com"
WA="limA@test.com"
WB="limB@test.com"

cleanup_fixture() {
    db_exec "DELETE FROM velocity_counter WHERE account_email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM velocity_profile WHERE profile_code LIKE 'LIM-V-%';"
    db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}')));"
    db_exec "DELETE FROM pending_transactions WHERE from_email IN ('${WA}','${WB}') OR to_email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM payment_profile WHERE user_email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM payment_policy WHERE currency_code='USD';"
    db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}'));"
    db_exec "DELETE FROM users WHERE email IN ('${WA}','${WB}');"
}
cleanup_fixture
for U in "$WA" "$WB"; do
    run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Lim T|1990-01-01" >/dev/null
    code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
    db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 10000.00 FROM users WHERE email='${U}';"
done
# Stray enabled USD profiles (other suites' leftovers share the currency
# namespace) would veto multi-transfer phases. Park them, restore at end.
STRAY="$(db_query "SELECT COALESCE(GROUP_CONCAT(profile_code SEPARATOR ' '),'') FROM velocity_profile WHERE currency_code='USD' AND enabled=TRUE AND profile_code NOT LIKE 'LIM-V-%';")"
if [ -n "$STRAY" ]; then
    # shellcheck disable=SC2086
    for P in $STRAY; do db_exec "UPDATE velocity_profile SET enabled=FALSE WHERE profile_code='${P}';"; done
fi
reset_usage() {
    db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}')));"
    db_exec "DELETE FROM pending_transactions WHERE from_email IN ('${WA}','${WB}') OR to_email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM velocity_counter WHERE account_email IN ('${WA}','${WB}');"
    db_exec "UPDATE accounts SET balance=10000.00 WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}'));"
}
bal() { db_query "SELECT balance FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='$1') AND currency_id=1;"; }

# 1-3. Env cap runs first and beats everything else.
run_cobol "PAY_POLICY_SET|USD|1000.00,100000.00,100,0,0|1|||${A}" >/dev/null
assert_match "policy set" "$(db_query "SELECT COUNT(*) FROM payment_policy WHERE currency_code='USD';")" "^1$"
TRANSFER_MAX_PER_TXN=5 run_cobol "TRANSFER|${WA}|${WB}|10.00|LIM-E1|||" > /tmp/lime1.out 2>&1 || true
assert_match "env cap blocks" "$(cat /tmp/lime1.out)" "ERROR\|LIMIT_EXCEEDED"
assert_match "env block moves no money" "$(bal "$WA")" "^10000.0000$"
assert_match "env ok without cap" "$(run_cobol "TRANSFER|${WA}|${WB}|10.00|LIM-E2|||")" "SUCCESS\|TRANSFER_OK"

# 4-6. Per-transaction policy cap, mirrored by CHECK.
run_cobol "PAY_POLICY_SET|USD|100.00,100000.00,100,0,0|1|||${A}" >/dev/null
assert_match "per-txn enforce" "$(run_cobol "PAY_ENFORCE|${WA}|USD|150.00|||${A}")" "SUCCESS\|PAY_ENFORCE\|BLOCKED\|PER_TXN"
assert_match "per-txn check mirrors" "$(run_cobol "PAY_CHECK|${WA}|USD|150.00|||${A}")" "SUCCESS\|PAY_CHECK\|BLOCKED\|PER_TXN"
assert_match "per-txn transfer" "$(run_cobol "TRANSFER|${WA}|${WB}|150.00|LIM-P1|||")" "ERROR\|LIMIT_EXCEEDED"

# 7-9. Daily amount policy cap with exact usage accounting.
reset_usage
run_cobol "PAY_POLICY_SET|USD|1000.00,120.00,100,0,0|1|||${A}" >/dev/null
assert_match "first 100 ok" "$(run_cobol "TRANSFER|${WA}|${WB}|100.00|LIM-D1|||")" "SUCCESS\|TRANSFER_OK"
assert_match "daily enforce" "$(run_cobol "PAY_ENFORCE|${WA}|USD|30.00|||${A}")" "SUCCESS\|PAY_ENFORCE\|BLOCKED\|DAILY_LIMIT"
assert_match "daily check mirrors" "$(run_cobol "PAY_CHECK|${WA}|USD|30.00|||${A}")" "SUCCESS\|PAY_CHECK\|BLOCKED\|DAILY_LIMIT"

# 10-12. Daily count policy cap.
reset_usage
run_cobol "PAY_POLICY_SET|USD|1000.00,100000.00,2,0,0|1|||${A}" >/dev/null
assert_match "count 1 ok" "$(run_cobol "TRANSFER|${WA}|${WB}|10.00|LIM-C1|||")" "SUCCESS\|TRANSFER_OK"
assert_match "count 2 ok" "$(run_cobol "TRANSFER|${WA}|${WB}|10.00|LIM-C2|||")" "SUCCESS\|TRANSFER_OK"
assert_match "count 3 blocked" "$(run_cobol "PAY_ENFORCE|${WA}|USD|10.00|||${A}")" "SUCCESS\|PAY_ENFORCE\|BLOCKED\|DAILY_COUNT"

# 13-15. Per-user profile override replaces the daily caps (tighter wins).
reset_usage
run_cobol "PAY_POLICY_SET|USD|1000.00,500.00,100,0,0|1|||${A}" >/dev/null
run_cobol "PAY_PROFILE_SET|${WA}|USD|50.00,100|1||${A}" >/dev/null
assert_match "override enforce" "$(run_cobol "PAY_ENFORCE|${WA}|USD|100.00|||${A}")" "SUCCESS\|PAY_ENFORCE\|BLOCKED\|DAILY_LIMIT"
assert_match "override check mirrors" "$(run_cobol "PAY_CHECK|${WA}|USD|100.00|||${A}")" "SUCCESS\|PAY_CHECK\|BLOCKED\|DAILY_LIMIT"
assert_match "override transfer" "$(run_cobol "TRANSFER|${WA}|${WB}|100.00|LIM-O1|||")" "ERROR\|DAILY_LIMIT_EXCEEDED"
db_exec "DELETE FROM payment_profile WHERE user_email='${WA}';"

# 16-18. First match wins: policy per-txn beats a velocity block.
reset_usage
run_cobol "PAY_POLICY_SET|USD|10.00,100000.00,100,0,0|1|||${A}" >/dev/null
run_cobol "VEL_PROFILE_CREATE|LIM-V-P|Priority|3600,0,100000.00,USD|||${A}" >/dev/null
assert_match "policy wins over velocity" "$(run_cobol "PAY_ENFORCE|${WA}|USD|50.00|||${A}")" "SUCCESS\|PAY_ENFORCE\|BLOCKED\|PER_TXN"
assert_match "velocity alone blocks" "$(run_cobol "PAY_ENFORCE|${WA}|USD|5.00|||${A}")" "SUCCESS\|PAY_ENFORCE\|BLOCKED\|VELOCITY"
assert_match "velocity check mirrors" "$(run_cobol "PAY_CHECK|${WA}|USD|5.00|||${A}")" "SUCCESS\|PAY_CHECK\|BLOCKED\|VELOCITY"
db_exec "DELETE FROM velocity_counter WHERE account_email IN ('${WA}','${WB}');"
db_exec "DELETE FROM velocity_profile WHERE profile_code='LIM-V-P';"

# 19-24. Velocity gates real transfers and records exactly once per commit.
reset_usage
run_cobol "PAY_POLICY_SET|USD|1000.00,100000.00,100,0,0|1|||${A}" >/dev/null
run_cobol "VEL_PROFILE_CREATE|LIM-V-W|Window|3600,1,5000.00,USD|||${A}" >/dev/null
assert_match "velocity T1 ok" "$(run_cobol "TRANSFER|${WA}|${WB}|10.00|LIM-V1|||")" "SUCCESS\|TRANSFER_OK"
assert_match "counter advanced once" "$(db_query "SELECT used_count FROM velocity_counter WHERE account_email='${WA}' AND profile_code='LIM-V-W';")" "^1$"
assert_match "velocity T2 blocked" "$(run_cobol "TRANSFER|${WA}|${WB}|10.00|LIM-V2|||")" "ERROR\|DAILY_LIMIT_EXCEEDED"
assert_match "blocked transfer moved no money" "$(bal "$WA")" "^9990.0000$"
assert_match "blocked transfer recorded nothing" "$(db_query "SELECT used_count FROM velocity_counter WHERE account_email='${WA}' AND profile_code='LIM-V-W';")" "^1$"
assert_match "enforce names velocity" "$(run_cobol "PAY_ENFORCE|${WA}|USD|10.00|||${A}")" "SUCCESS\|PAY_ENFORCE\|BLOCKED\|VELOCITY"

# 25-27. Disabled velocity profile stops vetoing; disabled policy passes.
db_exec "UPDATE velocity_profile SET enabled=FALSE WHERE profile_code='LIM-V-W';"
assert_match "disabled velocity ok" "$(run_cobol "TRANSFER|${WA}|${WB}|10.00|LIM-V3|||")" "SUCCESS\|TRANSFER_OK"
db_exec "UPDATE payment_policy SET enabled=FALSE WHERE currency_code='USD';"
assert_match "disabled policy ok" "$(run_cobol "PAY_ENFORCE|${WA}|USD|10.00|||${A}")" "SUCCESS\|PAY_ENFORCE\|OK\|0\|0\|POLICY_DISABLED"
assert_match "no policy ok" "$(db_exec "DELETE FROM payment_policy WHERE currency_code='USD';" >/dev/null; run_cobol "PAY_ENFORCE|${WA}|USD|10.00|||${A}")" "SUCCESS\|PAY_ENFORCE\|OK\|0\|0\|NO_POLICY"

# Restore parked profiles, then remove everything this suite owns.
if [ -n "$STRAY" ]; then
    # shellcheck disable=SC2086
    for P in $STRAY; do db_exec "UPDATE velocity_profile SET enabled=TRUE WHERE profile_code='${P}';"; done
fi
cleanup_fixture
print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
