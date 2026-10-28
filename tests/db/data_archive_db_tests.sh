#!/usr/bin/env bash
# Data archive (Wave5) end-to-end DB tests via the COBOL binary.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
if ! db_available; then echo "SKIP: DB unavailable"; exit 0; fi

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

db_seed
db_reset_data_archive

# Create a cost center.
create_out="$(run_cobol "DTA_CREATE|DTA-W5-1|ArchiveA|LOG|||admin@test.com")"
assert_match "DTA_CREATE ok" "$create_out" "SUCCESS\|DTA_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM data_archive WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DTA_CREATE|DTA-W5-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DTA_GET ok" "$(run_cobol "DTA_GET|${id}|||||admin@test.com")" "SUCCESS\|DTA_GET\|${id}\|DTA-W5-1"
assert_match "DTA_LIST ok" "$(run_cobol "DTA_LIST|||50|0||admin@test.com")" "DTA-W5-1"

# Allocate.
assert_match "DTA_CALC ok" "$(run_cobol "DTA_CALC|${id}|||||admin@test.com")" "SUCCESS\|DTA_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT stored_size FROM data_archive WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DTA_DELETE ok" "$(run_cobol "DTA_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|DTA_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM data_archive WHERE id=${id};")" "^PURGED$"

# Summary and audit.
assert_match "DTA_SUMMARY ok" "$(run_cobol "DTA_SUMMARY||||||admin@test.com")" "SUCCESS\|DTA_SUMMARY"
assert_match "DTA_AUDIT ok" "$(run_cobol "DTA_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DTA_AUDIT"
assert_match "DTA_VALIDATE ok" "$(run_cobol "DTA_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DTA_VALID"
assert_match "non-admin refused" "$(run_cobol "DTA_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0