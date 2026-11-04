#!/usr/bin/env bash
# Letter of credit (Wave4) end-to-end DB tests via the COBOL binary.
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
db_reset_letter_of_credit

# Create a cost center.
create_out="$(run_cobol "LOC_CREATE|LOC-W4-1|ApplicantA|STANDBY|||admin@test.com")"
assert_match "LOC_CREATE ok" "$create_out" "SUCCESS\|LOC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM letter_of_credit WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "LOC_CREATE|LOC-W4-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "LOC_GET ok" "$(run_cobol "LOC_GET|${id}|||||admin@test.com")" "SUCCESS\|LOC_GET\|${id}\|LOC-W4-1"
assert_match "LOC_LIST ok" "$(run_cobol "LOC_LIST|||50|0||admin@test.com")" "LOC-W4-1"

# Allocate.
assert_match "LOC_CALC ok" "$(run_cobol "LOC_CALC|${id}|||||admin@test.com")" "SUCCESS\|LOC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT drawn_amount FROM letter_of_credit WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "LOC_DELETE ok" "$(run_cobol "LOC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|LOC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM letter_of_credit WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "LOC_SUMMARY ok" "$(run_cobol "LOC_SUMMARY||||||admin@test.com")" "SUCCESS\|LOC_SUMMARY"
assert_match "LOC_AUDIT ok" "$(run_cobol "LOC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|LOC_AUDIT"
assert_match "LOC_VALIDATE ok" "$(run_cobol "LOC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|LOC_VALID"
assert_match "non-admin refused" "$(run_cobol "LOC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM letter_of_credit WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM letter_of_credit_audit WHERE letter_of_credit_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "LOC_UPDATE|${id}|ApplicantA|STANDBY|||admin@test.com")"
assert_match "LOC_UPDATE ok" "$upd_out" "SUCCESS\\|LOC_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM letter_of_credit WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM letter_of_credit_audit WHERE letter_of_credit_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "LOC_UPDATE|999999|ApplicantA|STANDBY|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "LOC_UPDATE|${id}|ApplicantA|STANDBY|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0