#!/usr/bin/env bash
# Admin/user shell coverage: inline app.js admin actions via run_cobol.
set -u
# Dormant lifecycle reads its policy from the environment; the COBOL server
# below inherits this process env, so the suite is deterministic anywhere.
export DORMANT_AFTER_DAYS=30
export DORMANT_GRACE_DAYS=0
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
db_exec "DELETE FROM account_holds WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email LIKE 'admsh%'));"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email LIKE 'admsh%@test.com');"
db_exec "DELETE FROM users WHERE email LIKE 'admsh%@test.com';"

C="admshC@test.com"
D="admshD@test.com"
run_cobol "REQUEST_SIGNUP|${C}|Passw0rd!|Admin See|1990-01-01" >/dev/null
ccode="$(db_query "SELECT code FROM verification_logs WHERE email='${C}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run_cobol "VERIFY_EMAIL|${C}|${ccode}" >/dev/null
run_cobol "REQUEST_SIGNUP|${D}|Passw0rd!|Admin Dee|1991-02-02" >/dev/null
dcode="$(db_query "SELECT code FROM verification_logs WHERE email='${D}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run_cobol "VERIFY_EMAIL|${D}|${dcode}" >/dev/null

# Reads.
assert_match "GET_USER ok" "$(run_cobol "GET_USER|${C}|admin@test.com")" "SUCCESS\|"
assert_match "GET_DASHBOARD ok" "$(run_cobol "GET_DASHBOARD|${C}|admin@test.com")" "SUCCESS\|"
assert_match "CHECK_ROLE ok" "$(run_cobol "CHECK_ROLE|${C}|USER|admin@test.com")" "SUCCESS\|"
assert_match "LIST_AUDIT ok" "$(run_cobol "LIST_AUDIT|admin@test.com|||50|0")" "SUCCESS\|"
assert_match "ARCHIVE_AUDIT noop window" "$(run_cobol "ARCHIVE_AUDIT|36500|admin@test.com")" "SUCCESS\|"

# Profile update is owner-only (actor must equal the account email).
assert_match "UPDATE_PROFILE ok" "$(run_cobol "UPDATE_PROFILE|${C}|Admin Changed|${C}|")" "SUCCESS\|"
assert_match "name persisted" "$(db_query "SELECT full_name FROM users WHERE email='${C}';")" "^Admin Changed$"

# Role + status lifecycle on C.
assert_match "CHANGE_ROLE ok" "$(run_cobol "CHANGE_ROLE|${C}|MANAGER|admin@test.com")" "SUCCESS\|"
assert_match "role persisted" "$(db_query "SELECT role FROM users WHERE email='${C}';")" "^MANAGER$"
assert_match "CHANGE_ROLE back" "$(run_cobol "CHANGE_ROLE|${C}|USER|admin@test.com")" "SUCCESS\|"
assert_match "SET_USER_STATUS suspend" "$(run_cobol "SET_USER_STATUS|${C}|SUSPENDED|admin@test.com")" "SUCCESS\|"
assert_match "status persisted" "$(db_query "SELECT status FROM users WHERE email='${C}';")" "^SUSPENDED$"
assert_match "UNLOCK_USER ok" "$(run_cobol "UNLOCK_USER|${C}|admin@test.com")" "SUCCESS\|"
assert_match "ADMIN_RESET_MFA ok" "$(run_cobol "ADMIN_RESET_MFA|${C}|admin@test.com")" "SUCCESS\|"
assert_match "SET_USER_STATUS verify" "$(run_cobol "SET_USER_STATUS|${C}|VERIFIED|admin@test.com")" "SUCCESS\|"

# Dormant lifecycle: age C past the window, mark, suspend, reactivate.
db_exec "UPDATE users SET last_login_at=DATE_SUB(NOW(), INTERVAL 60 DAY) WHERE email='${C}';"
assert_match "MARK_DORMANT ok" "$(run_cobol "MARK_DORMANT|admin@test.com")" "SUCCESS\|DORMANT_NOTIFIED\|"
assert_match "dormant flagged" "$(db_query "SELECT dormant_notified_at IS NOT NULL FROM users WHERE email='${C}';")" "^1$"
db_exec "UPDATE users SET dormant_notified_at=DATE_SUB(NOW(), INTERVAL 2 DAY) WHERE email='${C}';"
assert_match "SUSPEND_DORMANT ok" "$(run_cobol "SUSPEND_DORMANT|admin@test.com")" "SUCCESS\|DORMANT_SUSPENDED\|"
assert_match "dormant suspended" "$(db_query "SELECT status FROM users WHERE email='${C}';")" "^SUSPENDED$"
assert_match "REACTIVATE_DORMANT ok" "$(run_cobol "REACTIVATE_DORMANT|${C}|admin@test.com")" "SUCCESS\|DORMANT_REACTIVATED"
assert_match "reactivated" "$(db_query "SELECT status FROM users WHERE email='${C}';")" "^VERIFIED$"

# Holds need a real account row for the owner.
db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 1000.00 FROM users WHERE email='${C}';"
assert_match "PLACE_HOLD ok" "$(run_cobol "PLACE_HOLD|${C}|10.00|admin@test.com|||")" "SUCCESS\|"
holdid="$(db_query "SELECT hold_id FROM account_holds WHERE account_id=(SELECT account_id FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='${C}')) ORDER BY hold_id DESC LIMIT 1;")"
assert_match "hold row present" "$holdid" "^[0-9]+$"
assert_match "RELEASE_HOLD ok" "$(run_cobol "RELEASE_HOLD|${holdid}|admin@test.com")" "SUCCESS\|"
assert_match "hold released" "$(db_query "SELECT state FROM account_holds WHERE hold_id=${holdid};")" "^RELEASED$"
db_exec "DELETE FROM account_holds WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email LIKE 'admsh%'));"

# Email change on dedicated user D (email moves; use new address after).
D2="admshD2@test.com"
assert_match "REQ_EMAIL_CHANGE ok" "$(run_cobol "REQ_EMAIL_CHANGE|${D}|${D2}|${D}|Passw0rd!")" "SUCCESS\|"
ecode="$(db_query "SELECT code FROM verification_logs WHERE email='${D2}' AND purpose='EMAIL_CHANGE' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
assert_match "CONFIRM_EMAIL_CHANGE ok" "$(run_cobol "CONFIRM_EMAIL_CHANGE|${D}|${D2}|${ecode}|${D}")" "SUCCESS\|"
assert_match "email moved" "$(db_query "SELECT COUNT(*) FROM users WHERE email='${D2}';")" "^1$"

# Deactivate D2 last (owner-only; account closed; nothing later needs it).
assert_match "DEACTIVATE_ACCOUNT ok" "$(run_cobol "DEACTIVATE_ACCOUNT|${D2}|${D2}")" "SUCCESS\|"
assert_match "account closed" "$(db_query "SELECT status FROM users WHERE email='${D2}';")" "^CLOSED$"

db_exec "DELETE FROM account_holds WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email LIKE 'admsh%'));"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email LIKE 'admsh%@test.com');"
db_exec "DELETE FROM users WHERE email LIKE 'admsh%@test.com';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
