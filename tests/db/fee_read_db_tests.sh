#!/usr/bin/env bash
# Fee + GL read shell coverage: list actions via run_cobol.
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
db_exec "DELETE FROM fee_rule WHERE rule_code='FEE-SHELL-1';"
assert_match "FEE_RULE_CREATE ok (fixture)" "$(run_cobol "FEE_RULE_CREATE|FEE-SHELL-1|Shell Fee|FLAT|USD|10.00,0,0,0|${A}")" "SUCCESS\|FEE_RULE_CREATED"

assert_match "FEE_RULE_LIST ok" "$(run_cobol "FEE_RULE_LIST|50|0||||${A}")" "SUCCESS\|"
assert_match "FEE_TIER_LIST ok" "$(run_cobol "FEE_TIER_LIST|FEE-SHELL-1|50|0|||${A}")" "SUCCESS\|"
assert_match "FEE_WAIVER_LIST ok" "$(run_cobol "FEE_WAIVER_LIST|FEE-SHELL-1|50|0|||${A}")" "SUCCESS\|"
assert_match "GL_ACCOUNT_LIST ok" "$(run_cobol "GL_ACCOUNT_LIST|50|0||||${A}")" "SUCCESS\|"
assert_match "GL_PERIOD_LIST ok" "$(run_cobol "GL_PERIOD_LIST|50|0||||${A}")" "SUCCESS\|"
assert_match "GL_TRIAL_BALANCE ok" "$(run_cobol "GL_TRIAL_BALANCE|2026-01-01|2026-12-31|USD|||${A}")" "SUCCESS\|"
run_cobol "GL_PERIOD_OPEN|2026-06|||||${A}" >/dev/null
assert_match "GL_JOURNAL_POST_ML ok" "$(run_cobol "GL_JOURNAL_POST_ML|2026-06-01|test|USD|1000:10.00:0;1100:0:10.00||${A}")" "SUCCESS\|GL_POSTED"
assert_match "non-admin refused" "$(run_cobol "FEE_RULE_LIST|50|0||||sender@test.com")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM fee_rule WHERE rule_code='FEE-SHELL-1';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
