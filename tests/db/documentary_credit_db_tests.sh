#!/usr/bin/env bash
# Documentary credit (Wave16) end-to-end DB tests via the COBOL binary.
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
db_reset_documentary_credit

# Create a cost center.
create_out="$(run_cobol "DCRD_CREATE|DCRD-W16-1|ApplicantA|IRREVOCABLE|||admin@test.com")"
assert_match "DCRD_CREATE ok" "$create_out" "SUCCESS\|DCRD_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM documentary_credit WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DCRD_CREATE|DCRD-W16-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DCRD_GET ok" "$(run_cobol "DCRD_GET|${id}|||||admin@test.com")" "SUCCESS\|DCRD_GET\|${id}\|DCRD-W16-1"
assert_match "DCRD_LIST ok" "$(run_cobol "DCRD_LIST|||50|0||admin@test.com")" "DCRD-W16-1"

# Allocate.
assert_match "DCRD_CALC ok" "$(run_cobol "DCRD_CALC|${id}|||||admin@test.com")" "SUCCESS\|DCRD_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM documentary_credit WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DCRD_DELETE ok" "$(run_cobol "DCRD_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|DCRD_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM documentary_credit WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "DCRD_SUMMARY ok" "$(run_cobol "DCRD_SUMMARY||||||admin@test.com")" "SUCCESS\|DCRD_SUMMARY"
assert_match "DCRD_AUDIT ok" "$(run_cobol "DCRD_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DCRD_AUDIT"
assert_match "DCRD_VALIDATE ok" "$(run_cobol "DCRD_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DCRD_VALID"
assert_match "non-admin refused" "$(run_cobol "DCRD_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM documentary_credit WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM documentary_credit_audit WHERE documentary_credit_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "DCRD_UPDATE|${id}|ApplicantA|IRREVOCABLE|||admin@test.com")"
assert_match "DCRD_UPDATE ok" "$upd_out" "SUCCESS\\|DCRD_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM documentary_credit WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM documentary_credit_audit WHERE documentary_credit_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "DCRD_UPDATE|999999|ApplicantA|IRREVOCABLE|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "DCRD_UPDATE|${id}|ApplicantA|IRREVOCABLE|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0