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
# Dedicated far-future period: shared months get closed by month-end jobs
# outside any suite (2026-06 went CLOSED and broke this suite); 2099-03
# stays open and harmless.
run_cobol "GL_PERIOD_OPEN|2099-03|||||${A}" >/dev/null
assert_match "GL_JOURNAL_POST_ML ok" "$(run_cobol "GL_JOURNAL_POST_ML|2099-03-01|test|USD|1000:10.00:0;1100:0:10.00||${A}")" "SUCCESS\|GL_POSTED"
assert_match "non-admin refused" "$(run_cobol "FEE_RULE_LIST|50|0||||sender@test.com")" "ERROR\|FORBIDDEN"

# Fee rule update (P1-06): waiver/admin branches beyond the wallet path.
assert_match "FEE_RULE_UPDATE ok" "$(run_cobol "FEE_RULE_UPDATE|FEE-SHELL-1|1|5|10.00,0,0,0||${A}")" "SUCCESS\|FEE_RULE_UPDATED"
assert_match "rule enabled+priority persisted" "$(db_query "SELECT CONCAT(enabled, ':', priority) FROM fee_rule WHERE rule_code='FEE-SHELL-1';")" "^1:5$"
assert_match "update unknown rule" "$(run_cobol "FEE_RULE_UPDATE|NOPE-UNKNOWN|1|5|10.00,0,0,0||${A}")" "ERROR\|NOT_FOUND"
assert_match "update non-admin refused" "$(run_cobol "FEE_RULE_UPDATE|FEE-SHELL-1|1|5|10.00,0,0,0||sender@test.com")" "ERROR\|FORBIDDEN"

# Fee tiers (P1-06): create + list + guards.
assert_match "FEE_TIER_CREATE ok" "$(run_cobol "FEE_TIER_CREATE|FEE-SHELL-1|1|0.00|1000.00|1.00,0.05|${A}")" "SUCCESS\|FEE_TIER_CREATED"
assert_match "tier persisted" "$(db_query "SELECT COUNT(*) FROM fee_tier WHERE rule_id=(SELECT id FROM fee_rule WHERE rule_code='FEE-SHELL-1') AND tier_no=1;")" "^1$"
assert_match "tier unknown rule" "$(run_cobol "FEE_TIER_CREATE|NOPE-UNKNOWN|1|0.00|1000.00|1.00,0.05|${A}")" "ERROR\|NOT_FOUND"
assert_match "tier missing input" "$(run_cobol "FEE_TIER_CREATE|FEE-SHELL-1|||||${A}")" "ERROR\|INVALID_INPUT"
assert_match "FEE_TIER_LIST shows tier" "$(run_cobol "FEE_TIER_LIST|FEE-SHELL-1|50|0|||${A}")" "SUCCESS\|FEE_TIERS\|1\|1:"

# Fee waivers (P1-06): create + list + guards.
assert_match "FEE_WAIVER_CREATE ok" "$(run_cobol "FEE_WAIVER_CREATE|FEE-SHELL-1|sender@test.com|P1-06 probe|2026-01-01|2027-01-01|${A}")" "SUCCESS\|FEE_WAIVER_CREATED"
assert_match "FEE_WAIVER_LIST shows waiver" "$(run_cobol "FEE_WAIVER_LIST|FEE-SHELL-1|50|0|||${A}")" "sender@test.com"
assert_match "waiver bad email" "$(run_cobol "FEE_WAIVER_CREATE|FEE-SHELL-1|not-an-email|P1-06|2026-01-01|2027-01-01|${A}")" "ERROR\|INVALID_INPUT"
assert_match "waiver unknown rule" "$(run_cobol "FEE_WAIVER_CREATE|NOPE-UNKNOWN|sender@test.com|P1-06|2026-01-01|2027-01-01|${A}")" "ERROR\|NOT_FOUND"

# Fee calculate (P1-06): waived vs plain + guards.
assert_match "FEE_CALCULATE waived to zero" "$(run_cobol "FEE_CALCULATE|sender@test.com|FEE-SHELL-1|100.00|USD||${A}")" "SUCCESS\|FEE_CALC\|0"
assert_match "FEE_CALCULATE plain flat" "$(run_cobol "FEE_CALCULATE|receiver@test.com|FEE-SHELL-1|100.00|USD||${A}")" "SUCCESS\|FEE_CALC\|10"
assert_match "calculate unknown rule" "$(run_cobol "FEE_CALCULATE|sender@test.com|NOPE-UNKNOWN|100.00|USD||${A}")" "ERROR\|RULE_NOT_FOUND"
assert_match "calculate non-admin refused" "$(run_cobol "FEE_CALCULATE|sender@test.com|FEE-SHELL-1|100.00|USD||sender@test.com")" "ERROR\|FORBIDDEN"

# GL accounts (P1-06): create + guards.
assert_match "GL_ACCOUNT_CREATE ok" "$(run_cobol "GL_ACCOUNT_CREATE|TST-8100|Test Asset|ASSET|DEBIT||${A}")" "SUCCESS\|GL_ACCOUNT_CREATED"
assert_match "account persisted" "$(db_query "SELECT COUNT(*) FROM gl_account WHERE account_code='TST-8100';")" "^1$"
assert_match "account duplicate" "$(run_cobol "GL_ACCOUNT_CREATE|TST-8100|Test Asset|ASSET|DEBIT||${A}")" "ERROR\|DUPLICATE"
assert_match "account bad type" "$(run_cobol "GL_ACCOUNT_CREATE|TST-8101|Test|NOPE|DEBIT||${A}")" "ERROR\|INVALID_TYPE"
assert_match "account non-admin refused" "$(run_cobol "GL_ACCOUNT_CREATE|TST-8102|Test|ASSET|DEBIT||sender@test.com")" "ERROR\|FORBIDDEN"

# GL period close (P1-06): dedicated far-future month, closed twice.
db_exec "DELETE FROM gl_period WHERE period_code='2099-04';"
run_cobol "GL_PERIOD_OPEN|2099-04|||||${A}" >/dev/null
assert_match "GL_PERIOD_CLOSE ok" "$(run_cobol "GL_PERIOD_CLOSE|2099-04|||||${A}")" "SUCCESS\|GL_PERIOD_CLOSED"
assert_match "period closed persisted" "$(db_query "SELECT status FROM gl_period WHERE period_code='2099-04';")" "^CLOSED$"
assert_match "close already closed" "$(run_cobol "GL_PERIOD_CLOSE|2099-04|||||${A}")" "ERROR\|INVALID_STATUS"
assert_match "close bad period" "$(run_cobol "GL_PERIOD_CLOSE|BAD|||||${A}")" "ERROR\|INVALID_PERIOD"

# GL single journal guards (P1-06): no valid posting needed for these.
assert_match "journal same account" "$(run_cobol "GL_JOURNAL_POST|2099-03-01|test|1000|1000|USD:10.00|${A}")" "ERROR\|SAME_ACCOUNT"
assert_match "journal bad currency" "$(run_cobol "GL_JOURNAL_POST|2099-03-01|test|1000|1100|12:10.00|${A}")" "ERROR\|INVALID_CURRENCY"
assert_match "journal unknown accounts" "$(run_cobol "GL_JOURNAL_POST|2099-03-01|test|9998|9999|USD:10.00|${A}")" "ERROR\|ACCOUNT_NOT_FOUND"
assert_match "journal non-admin refused" "$(run_cobol "GL_JOURNAL_POST|2099-03-01|test|1000|1100|USD:10.00|sender@test.com")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM gl_account WHERE account_code IN ('TST-8100','TST-8101','TST-8102');"
db_exec "DELETE FROM fee_rule WHERE rule_code='FEE-SHELL-1';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
