#!/usr/bin/env bash
# Repo agreement (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_repo_agreement

# Create a cost center.
create_out="$(run_cobol "RPO_CREATE|RPO-W6-1|BorrowerA|OVERNIGHT|||admin@test.com")"
assert_match "RPO_CREATE ok" "$create_out" "SUCCESS\|RPO_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM repo_agreement WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RPO_CREATE|RPO-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RPO_GET ok" "$(run_cobol "RPO_GET|${id}|||||admin@test.com")" "SUCCESS\|RPO_GET\|${id}\|RPO-W6-1"
assert_match "RPO_LIST ok" "$(run_cobol "RPO_LIST|||50|0||admin@test.com")" "RPO-W6-1"

# Allocate.
assert_match "RPO_CALC ok" "$(run_cobol "RPO_CALC|${id}|||||admin@test.com")" "SUCCESS\|RPO_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM repo_agreement WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "RPO_DELETE ok" "$(run_cobol "RPO_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|RPO_DELETE"
assert_match "matured persisted" "$(db_query "SELECT status FROM repo_agreement WHERE id=${id};")" "^MATURED$"

# Summary and audit.
assert_match "RPO_SUMMARY ok" "$(run_cobol "RPO_SUMMARY||||||admin@test.com")" "SUCCESS\|RPO_SUMMARY"
assert_match "RPO_AUDIT ok" "$(run_cobol "RPO_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RPO_AUDIT"
assert_match "RPO_VALIDATE ok" "$(run_cobol "RPO_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RPO_VALID"
assert_match "non-admin refused" "$(run_cobol "RPO_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM repo_agreement WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM repo_agreement_audit WHERE repo_agreement_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "RPO_UPDATE|${id}|BorrowerA|OVERNIGHT|||admin@test.com")"
assert_match "RPO_UPDATE ok" "$upd_out" "SUCCESS\\|RPO_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM repo_agreement WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM repo_agreement_audit WHERE repo_agreement_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "RPO_UPDATE|999999|BorrowerA|OVERNIGHT|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "RPO_UPDATE|${id}|BorrowerA|OVERNIGHT|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0