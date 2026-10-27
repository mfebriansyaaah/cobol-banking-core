#!/usr/bin/env bash
# document (Wave1) end-to-end DB tests via the COBOL binary.
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
db_reset_document

# Create a cost center.
create_out="$(run_cobol "DOC_CREATE|DOC-W1-1|Agreement|PDF|||admin@test.com")"
assert_match "DOC_CREATE ok" "$create_out" "SUCCESS\|DOC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM document WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DOC_CREATE|DOC-W1-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DOC_GET ok" "$(run_cobol "DOC_GET|${id}|||||admin@test.com")" "SUCCESS\|DOC_GET\|${id}\|DOC-W1-1"
assert_match "DOC_LIST ok" "$(run_cobol "DOC_LIST|||50|0||admin@test.com")" "DOC-W1-1"

# Allocate.
assert_match "DOC_CALC ok" "$(run_cobol "DOC_CALC|${id}|||||admin@test.com")" "SUCCESS\|DOC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT file_version FROM document WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DOC_DELETE ok" "$(run_cobol "DOC_DELETE|${id}|ARCHIVED||||admin@test.com")" "SUCCESS\|DOC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM document WHERE id=${id};")" "^ARCHIVED$"

# Summary and audit.
assert_match "DOC_SUMMARY ok" "$(run_cobol "DOC_SUMMARY||||||admin@test.com")" "SUCCESS\|DOC_SUMMARY"
assert_match "DOC_AUDIT ok" "$(run_cobol "DOC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DOC_AUDIT"
assert_match "DOC_VALIDATE ok" "$(run_cobol "DOC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DOC_VALID"
assert_match "non-admin refused" "$(run_cobol "DOC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0