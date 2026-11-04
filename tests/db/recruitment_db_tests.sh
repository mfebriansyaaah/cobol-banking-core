#!/usr/bin/env bash
# Recruitment (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_recruitment

# Create a cost center.
create_out="$(run_cobol "REC_CREATE|REC-W10-1|CandidateA|FULL_TIME|||admin@test.com")"
assert_match "REC_CREATE ok" "$create_out" "SUCCESS\|REC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM recruitment WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "REC_CREATE|REC-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "REC_GET ok" "$(run_cobol "REC_GET|${id}|||||admin@test.com")" "SUCCESS\|REC_GET\|${id}\|REC-W10-1"
assert_match "REC_LIST ok" "$(run_cobol "REC_LIST|||50|0||admin@test.com")" "REC-W10-1"

# Allocate.
assert_match "REC_CALC ok" "$(run_cobol "REC_CALC|${id}|||||admin@test.com")" "SUCCESS\|REC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM recruitment WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "REC_DELETE ok" "$(run_cobol "REC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|REC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM recruitment WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "REC_SUMMARY ok" "$(run_cobol "REC_SUMMARY||||||admin@test.com")" "SUCCESS\|REC_SUMMARY"
assert_match "REC_AUDIT ok" "$(run_cobol "REC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|REC_AUDIT"
assert_match "REC_VALIDATE ok" "$(run_cobol "REC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|REC_VALID"
assert_match "non-admin refused" "$(run_cobol "REC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM recruitment WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM recruitment_audit WHERE recruitment_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "REC_UPDATE|${id}|CandidateA|FULL_TIME|||admin@test.com")"
assert_match "REC_UPDATE ok" "$upd_out" "SUCCESS\\|REC_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM recruitment WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM recruitment_audit WHERE recruitment_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "REC_UPDATE|999999|CandidateA|FULL_TIME|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "REC_UPDATE|${id}|CandidateA|FULL_TIME|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0