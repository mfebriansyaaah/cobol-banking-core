#!/usr/bin/env bash
# Geo/device risk notations (PR-092): record, latest-wins status, auth gates.
# Raw IPs never reach COBOL (hash only); signals never block.
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
U="riskU@test.com"
H="e4bneo6hashplaceholder0000000000000000000000000000000000000000000000"
cleanup() {
    db_exec "DELETE FROM risk_events WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
    db_exec "DELETE FROM users WHERE email='${U}';"
}
cleanup
run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Risk You|1990-01-01" >/dev/null
code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
REALH="$(node -e "console.log(require('crypto').createHash('sha256').update('203.0.113.7').digest('hex'))")"

assert_match "status with no events" "$(run_cobol "RISK_STATUS|${U}|||||${U}")" "SUCCESS\|RISK_STATUS\|NO_EVENTS"
assert_match "missing hash refused" "$(run_cobol "RISK_NOTE|${U}|ID|Jakarta|AS1||${U}")" "ERROR\|INVALID_INPUT"
assert_match "missing user refused" "$(run_cobol "RISK_NOTE|nobody@test.com|ID|Jakarta|AS1|${H}|nobody@test.com")" "ERROR\|ACCOUNT_NOT_FOUND"
assert_match "foreign actor refused" "$(run_cobol "RISK_NOTE|${U}|ID|Jakarta|AS1|${H}|sender@test.com")" "ERROR\|FORBIDDEN"
assert_match "stranger cannot read" "$(run_cobol "RISK_STATUS|${U}|||||sender@test.com")" "ERROR\|FORBIDDEN"
assert_match "note ok" "$(run_cobol "RISK_NOTE|${U}|ID|Jakarta|AS1|${REALH}|${U}")" "SUCCESS\|RISK_NOTED"
assert_match "hash stored, raw absent" "$(db_query "SELECT ip_hash FROM risk_events WHERE user_id=(SELECT id FROM users WHERE email='${U}') ORDER BY id DESC LIMIT 1;")" "^[0-9a-f]{64}$"
assert_match "status latest" "$(run_cobol "RISK_STATUS|${U}|||||${U}")" "SUCCESS\|RISK_STATUS\|ID\|"
assert_match "admin can read" "$(run_cobol "RISK_STATUS|${U}|||||${A}")" "SUCCESS\|RISK_STATUS\|ID\|"
assert_match "flagged note" "$(run_cobol "RISK_NOTE|${U}|US|Dallas|AS2|${REALH}:COUNTRY_MISMATCH|${U}")" "SUCCESS\|RISK_NOTED"
assert_match "latest wins" "$(run_cobol "RISK_STATUS|${U}|||||${U}")" "SUCCESS\|RISK_STATUS\|US\|COUNTRY_MISMATCH"
assert_match "unknown geo note" "$(run_cobol "RISK_NOTE|${U}|UNKNOWN|||${REALH}:GEO_UNKNOWN|${U}")" "SUCCESS\|RISK_NOTED"
assert_match "unknown served" "$(run_cobol "RISK_STATUS|${U}|||||${U}")" "SUCCESS\|RISK_STATUS\|UNKNOWN\|GEO_UNKNOWN"

cleanup

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
