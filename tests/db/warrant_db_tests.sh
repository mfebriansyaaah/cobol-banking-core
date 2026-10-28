#!/usr/bin/env bash
# Warrant (Wave12) end-to-end DB tests via the COBOL binary.
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
db_reset_warrant

# Create a cost center.
create_out="$(run_cobol "WAR_CREATE|WAR-W12-1|WarrantA|CALL|||admin@test.com")"
assert_match "WAR_CREATE ok" "$create_out" "SUCCESS\|WAR_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM warrant WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "WAR_CREATE|WAR-W12-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "WAR_GET ok" "$(run_cobol "WAR_GET|${id}|||||admin@test.com")" "SUCCESS\|WAR_GET\|${id}\|WAR-W12-1"
assert_match "WAR_LIST ok" "$(run_cobol "WAR_LIST|||50|0||admin@test.com")" "WAR-W12-1"

# Allocate.
assert_match "WAR_CALC ok" "$(run_cobol "WAR_CALC|${id}|||||admin@test.com")" "SUCCESS\|WAR_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM warrant WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "WAR_DELETE ok" "$(run_cobol "WAR_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|WAR_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM warrant WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "WAR_SUMMARY ok" "$(run_cobol "WAR_SUMMARY||||||admin@test.com")" "SUCCESS\|WAR_SUMMARY"
assert_match "WAR_AUDIT ok" "$(run_cobol "WAR_AUDIT|50|0||||admin@test.com")" "SUCCESS\|WAR_AUDIT"
assert_match "WAR_VALIDATE ok" "$(run_cobol "WAR_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|WAR_VALID"
assert_match "non-admin refused" "$(run_cobol "WAR_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0