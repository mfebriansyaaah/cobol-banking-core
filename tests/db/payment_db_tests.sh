#!/usr/bin/env bash
# Payment policy engine (PR-4b): set/get/list + check/enforce + audit.
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
db_exec "DELETE FROM payment_policy WHERE currency_code='ZZZ';"
db_exec "DELETE FROM payment_profile WHERE currency_code='ZZZ';"
db_exec "DELETE FROM payment_audit WHERE currency_code='ZZZ';"

assert_match "policy set ok" "$(run_cobol "PAY_POLICY_SET|ZZZ|1000.00,5000.00,10,500.00,50.00|1|||${A}")" "SUCCESS\|PAY_POLICY_SET"
assert_match "policy persisted" "$(db_query "SELECT max_per_txn FROM payment_policy WHERE currency_code='ZZZ';")" "^1000"
assert_match "policy audited" "$(db_query "SELECT COUNT(*) FROM payment_audit WHERE currency_code='ZZZ' AND action='POLICY_SET';")" "^1$"
assert_match "policy get ok" "$(run_cobol "PAY_POLICY_GET|ZZZ|||||${A}")" "SUCCESS\|PAY_POLICY"
assert_match "policy list ok" "$(run_cobol "PAY_POLICY_LIST|50|0|ZZZ|||${A}")" "ZZZ"
assert_match "check within limits" "$(run_cobol "PAY_CHECK|sender@test.com|ZZZ|100|||${A}")" "SUCCESS\|PAY_CHECK\|"
assert_match "enforce within limits" "$(run_cobol "PAY_ENFORCE|sender@test.com|ZZZ|100|||${A}")" "SUCCESS\|PAY_ENFORCE\|"

assert_match "policy set missing params" "$(run_cobol "PAY_POLICY_SET|ZZZ|||||${A}")" "ERROR\|INVALID_INPUT"
assert_match "policy set non-admin refused" "$(run_cobol "PAY_POLICY_SET|ZZZ|1,1,1,1,1|1|||sender@test.com")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM payment_policy WHERE currency_code='ZZZ';"
db_exec "DELETE FROM payment_profile WHERE currency_code='ZZZ';"
db_exec "DELETE FROM payment_audit WHERE currency_code='ZZZ';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
