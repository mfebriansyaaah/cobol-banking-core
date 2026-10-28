#!/usr/bin/env bash
# Backup management (Wave5) end-to-end DB tests via the COBOL binary.
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
db_reset_backup_management

# Create a cost center.
create_out="$(run_cobol "BUM_CREATE|BUM-W5-1|BackupA|FULL|||admin@test.com")"
assert_match "BUM_CREATE ok" "$create_out" "SUCCESS\|BUM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM backup_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "BUM_CREATE|BUM-W5-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "BUM_GET ok" "$(run_cobol "BUM_GET|${id}|||||admin@test.com")" "SUCCESS\|BUM_GET\|${id}\|BUM-W5-1"
assert_match "BUM_LIST ok" "$(run_cobol "BUM_LIST|||50|0||admin@test.com")" "BUM-W5-1"

# Allocate.
assert_match "BUM_CALC ok" "$(run_cobol "BUM_CALC|${id}|||||admin@test.com")" "SUCCESS\|BUM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT completed_backups FROM backup_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "BUM_DELETE ok" "$(run_cobol "BUM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|BUM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM backup_management WHERE id=${id};")" "^COMPLETED$"

# Summary and audit.
assert_match "BUM_SUMMARY ok" "$(run_cobol "BUM_SUMMARY||||||admin@test.com")" "SUCCESS\|BUM_SUMMARY"
assert_match "BUM_AUDIT ok" "$(run_cobol "BUM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|BUM_AUDIT"
assert_match "BUM_VALIDATE ok" "$(run_cobol "BUM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|BUM_VALID"
assert_match "non-admin refused" "$(run_cobol "BUM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0