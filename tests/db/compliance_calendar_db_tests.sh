#!/usr/bin/env bash
# Compliance calendar (Wave3) end-to-end DB tests via the COBOL binary.
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
db_reset_compliance_calendar

# Create a cost center.
create_out="$(run_cobol "CCL_CREATE|CCL-W3-1|EventA|REG|||admin@test.com")"
assert_match "CCL_CREATE ok" "$create_out" "SUCCESS\|CCL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM compliance_calendar WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CCL_CREATE|CCL-W3-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CCL_GET ok" "$(run_cobol "CCL_GET|${id}|||||admin@test.com")" "SUCCESS\|CCL_GET\|${id}\|CCL-W3-1"
assert_match "CCL_LIST ok" "$(run_cobol "CCL_LIST|||50|0||admin@test.com")" "CCL-W3-1"

# Allocate.
assert_match "CCL_CALC ok" "$(run_cobol "CCL_CALC|${id}|||||admin@test.com")" "SUCCESS\|CCL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT completed_events FROM compliance_calendar WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CCL_DELETE ok" "$(run_cobol "CCL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CCL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM compliance_calendar WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CCL_SUMMARY ok" "$(run_cobol "CCL_SUMMARY||||||admin@test.com")" "SUCCESS\|CCL_SUMMARY"
assert_match "CCL_AUDIT ok" "$(run_cobol "CCL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CCL_AUDIT"
assert_match "CCL_VALIDATE ok" "$(run_cobol "CCL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CCL_VALID"
assert_match "non-admin refused" "$(run_cobol "CCL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM compliance_calendar WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM compliance_calendar_audit WHERE compliance_calendar_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "CCL_UPDATE|${id}|EventA|REG|||admin@test.com")"
assert_match "CCL_UPDATE ok" "$upd_out" "SUCCESS\\|CCL_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM compliance_calendar WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM compliance_calendar_audit WHERE compliance_calendar_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "CCL_UPDATE|999999|EventA|REG|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "CCL_UPDATE|${id}|EventA|REG|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0