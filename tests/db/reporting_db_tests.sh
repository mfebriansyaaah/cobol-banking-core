#!/usr/bin/env bash
# Reporting (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_reporting

# Create a cost center.
create_out="$(run_cobol "RPTG_CREATE|RPTG-W10-1|ReportA|DAILY|||admin@test.com")"
assert_match "RPTG_CREATE ok" "$create_out" "SUCCESS\|RPTG_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM reporting WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RPTG_CREATE|RPTG-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RPTG_GET ok" "$(run_cobol "RPTG_GET|${id}|||||admin@test.com")" "SUCCESS\|RPTG_GET\|${id}\|RPTG-W10-1"
assert_match "RPTG_LIST ok" "$(run_cobol "RPTG_LIST|||50|0||admin@test.com")" "RPTG-W10-1"

# Allocate.
assert_match "RPTG_CALC ok" "$(run_cobol "RPTG_CALC|${id}|||||admin@test.com")" "SUCCESS\|RPTG_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM reporting WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "RPTG_DELETE ok" "$(run_cobol "RPTG_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|RPTG_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM reporting WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "RPTG_SUMMARY ok" "$(run_cobol "RPTG_SUMMARY||||||admin@test.com")" "SUCCESS\|RPTG_SUMMARY"
assert_match "RPTG_AUDIT ok" "$(run_cobol "RPTG_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RPTG_AUDIT"
assert_match "RPTG_VALIDATE ok" "$(run_cobol "RPTG_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RPTG_VALID"
assert_match "non-admin refused" "$(run_cobol "RPTG_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM reporting WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM reporting_audit WHERE reporting_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "RPTG_UPDATE|${id}|ReportA|DAILY|||admin@test.com")"
assert_match "RPTG_UPDATE ok" "$upd_out" "SUCCESS\\|RPTG_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM reporting WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM reporting_audit WHERE reporting_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "RPTG_UPDATE|999999|ReportA|DAILY|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "RPTG_UPDATE|${id}|ReportA|DAILY|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0