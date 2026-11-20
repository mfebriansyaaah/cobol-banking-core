#!/usr/bin/env bash
# Tax management DB tests via the COBOL binary.
# Generic CREATE/UPDATE/DELETE removed (PR-2d): rule lifecycle via
# TXM_RULE_* is the real surface; enable/disable is RULE_UPDATE P4.
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
db_reset_tax_management

# Removed generic actions are gone.
assert_match "TXM_CREATE removed" "$(run_cobol "TXM_CREATE|X|X|VAT|||admin@test.com")" "ERROR\|INVALID_ACTION"
assert_match "TXM_UPDATE removed" "$(run_cobol "TXM_UPDATE|1|X|VAT|||admin@test.com")" "ERROR\|INVALID_ACTION"
assert_match "TXM_DELETE removed" "$(run_cobol "TXM_DELETE|1|X||||admin@test.com")" "ERROR\|INVALID_ACTION"

# Rule create is the only creation path.
rid_out="$(run_cobol "TXM_RULE_CREATE|TXR-D1|PPh 21|WITHHOLDING|5:0:50000:1000000|IDR:5000:2026-01-01:|admin@test.com")"
assert_match "rule create" "$rid_out" "SUCCESS\|TXM_RULE_CREATE\|[0-9]+"
rid="$(printf '%s' "$rid_out" | awk -F'|' '{print $3}')"
assert_match "rule persisted" "$(db_query "SELECT rate_pct FROM tax_management WHERE id=${rid};")" "^5"
assert_match "duplicate rule" "$(run_cobol "TXM_RULE_CREATE|TXR-D1|PPh 21|WITHHOLDING|5:0:50000:1000000|IDR:5000:2026-01-01:|admin@test.com")" "ERROR\|DUPLICATE"
assert_match "bad rate" "$(run_cobol "TXM_RULE_CREATE|TXR-X|X|WITHHOLDING|101:0:0:0|IDR:5000:2026-01-01:|admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "rule create missing ref" "$(run_cobol "TXM_RULE_CREATE||||||admin@test.com")" "ERROR\|INVALID_INPUT"

# Read paths.
assert_match "TXM_RULE_GET ok" "$(run_cobol "TXM_RULE_GET|${rid}|||||admin@test.com")" "SUCCESS\|TXM_RULE_GET"
assert_match "TXM_RULE_LIST ok" "$(run_cobol "TXM_RULE_LIST|||50|0||admin@test.com")" "TXR-D1"
assert_match "TXM_GET ok" "$(run_cobol "TXM_GET|${rid}|||||admin@test.com")" "SUCCESS\|TXM_GET\|${rid}\|TXR-D1"
assert_match "TXM_LIST ok" "$(run_cobol "TXM_LIST|||50|0||admin@test.com")" "TXR-D1"
assert_match "non-admin read refused" "$(run_cobol "TXM_RULE_GET|${rid}|||||sender@test.com")" "ERROR\|FORBIDDEN"

# Rule update: rate change.
assert_match "rule update" "$(run_cobol "TXM_RULE_UPDATE|${rid}|10:0:50000:1000000||||admin@test.com")" "SUCCESS\|TXM_RULE_UPDATE"
assert_match "rate persisted" "$(db_query "SELECT rate_pct FROM tax_management WHERE id=${rid};")" "^10"

# Enable/disable is RULE_UPDATE P4 (no separate RULE_DISABLE action).
assert_match "rule disable" "$(run_cobol "TXM_RULE_UPDATE|${rid}|||FALSE||admin@test.com")" "SUCCESS\|TXM_RULE_UPDATE"
assert_match "disabled persisted" "$(db_query "SELECT enabled FROM tax_management WHERE id=${rid};")" "^0$"
assert_match "calc while disabled" "$(run_cobol "TXM_CALC|${rid}|FEE|FEE-DD|1000000|IDR|admin@test.com")" "ERROR\|INVALID_STATE"
assert_match "rule enable" "$(run_cobol "TXM_RULE_UPDATE|${rid}|||TRUE||admin@test.com")" "SUCCESS\|TXM_RULE_UPDATE"
assert_match "enabled persisted" "$(db_query "SELECT enabled FROM tax_management WHERE id=${rid};")" "^1$"

# Calc -> post -> reverse happy path (rule id is P1).
calc_out="$(run_cobol "TXM_CALC|${rid}|FEE|FEE-D1|1000000|IDR|admin@test.com")"
assert_match "calc ok" "$calc_out" "SUCCESS\|TXM_CALC\|[0-9]+\|100000"
eid="$(printf '%s' "$calc_out" | awk -F'|' '{print $3}')"
assert_match "entry calculated" "$(db_query "SELECT status FROM tax_withholding_entry WHERE entry_id=${eid};")" "^CALCULATED$"
assert_match "post ok" "$(run_cobol "TXM_POST|${eid}|777||||admin@test.com")" "SUCCESS\|TXM_POST"
assert_match "posted persisted" "$(db_query "SELECT status FROM tax_withholding_entry WHERE entry_id=${eid};")" "^POSTED$"
assert_match "gl linked" "$(db_query "SELECT gl_journal_id FROM tax_withholding_entry WHERE entry_id=${eid};")" "^777$"
assert_match "reverse ok" "$(run_cobol "TXM_REVERSE|${eid}|koreksi||||admin@test.com")" "SUCCESS\|TXM_REVERSE"
assert_match "reversed persisted" "$(db_query "SELECT status FROM tax_withholding_entry WHERE entry_id=${eid};")" "^REVERSED$"

# Report run.
assert_match "report ok" "$(run_cobol "TXM_REPORT|2026-11|WITHHOLDING|IDR|||admin@test.com")" "SUCCESS\|TXM_REPORT"
assert_match "report persisted" "$(db_query "SELECT COUNT(*) FROM tax_report_run;")" "^[1-9]"

# Summary and audit.
assert_match "TXM_SUMMARY ok" "$(run_cobol "TXM_SUMMARY||||||admin@test.com")" "SUCCESS\|TXM_SUMMARY"
assert_match "TXM_AUDIT ok" "$(run_cobol "TXM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TXM_AUDIT"
assert_match "TXM_VALIDATE ok" "$(run_cobol "TXM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TXM_VALID"
assert_match "non-admin calc refused" "$(run_cobol "TXM_CALC|${rid}|FEE|FEE-DZ|100|IDR|sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
