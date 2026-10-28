#!/usr/bin/env bash
# AML screening (D11) end-to-end DB tests via the COBOL binary.
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
db_reset_aml_screening

# Create a screening.
create_out="$(run_cobol "AML_CREATE|AML-D11-1|John Doe|PEP|||admin@test.com")"
assert_match "AML_CREATE ok" "$create_out" "SUCCESS\|AML_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM aml_screening WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "AML_CREATE|AML-D11-1|Other|SANCTIONS|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "AML_GET ok" "$(run_cobol "AML_GET|${id}|||||admin@test.com")" "SUCCESS\|AML_GET\|${id}\|AML-D11-1"
assert_match "AML_LIST ok" "$(run_cobol "AML_LIST||PEP|50|0||admin@test.com")" "AML-D11-1"

# Screen.
assert_match "AML_SCREEN ok" "$(run_cobol "AML_SCREEN|${id}|||||admin@test.com")" "SUCCESS\|AML_SCREEN\|1"
assert_match "hit_count persisted" "$(db_query "SELECT hit_count FROM aml_screening WHERE id=${id};")" "^1$"

# Close.
assert_match "AML_CLOSE ok" "$(run_cobol "AML_CLOSE|${id}|Cleared||||admin@test.com")" "SUCCESS\|AML_CLOSE"
assert_match "closed persisted" "$(db_query "SELECT status FROM aml_screening WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "AML_SUMMARY ok" "$(run_cobol "AML_SUMMARY||||||admin@test.com")" "SUCCESS\|AML_SUMMARY"
assert_match "AML_AUDIT ok" "$(run_cobol "AML_AUDIT|50|0||||admin@test.com")" "SUCCESS\|AML_AUDIT"
assert_match "AML_VALIDATE ok" "$(run_cobol "AML_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|AML_VALID"
assert_match "non-admin refused" "$(run_cobol "AML_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0