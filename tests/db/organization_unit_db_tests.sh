#!/usr/bin/env bash
# Organization unit (Wave5) end-to-end DB tests via the COBOL binary.
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
db_reset_organization_unit

# Create a cost center.
create_out="$(run_cobol "ORG_CREATE|ORG-W5-1|OrgA|DEPT|||admin@test.com")"
assert_match "ORG_CREATE ok" "$create_out" "SUCCESS\|ORG_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM organization_unit WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ORG_CREATE|ORG-W5-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ORG_GET ok" "$(run_cobol "ORG_GET|${id}|||||admin@test.com")" "SUCCESS\|ORG_GET\|${id}\|ORG-W5-1"
assert_match "ORG_LIST ok" "$(run_cobol "ORG_LIST|||50|0||admin@test.com")" "ORG-W5-1"

# Allocate.
assert_match "ORG_CALC ok" "$(run_cobol "ORG_CALC|${id}|||||admin@test.com")" "SUCCESS\|ORG_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT member_count FROM organization_unit WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ORG_DELETE ok" "$(run_cobol "ORG_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ORG_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM organization_unit WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "ORG_SUMMARY ok" "$(run_cobol "ORG_SUMMARY||||||admin@test.com")" "SUCCESS\|ORG_SUMMARY"
assert_match "ORG_AUDIT ok" "$(run_cobol "ORG_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ORG_AUDIT"
assert_match "ORG_VALIDATE ok" "$(run_cobol "ORG_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ORG_VALID"
assert_match "non-admin refused" "$(run_cobol "ORG_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM organization_unit WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM organization_unit_audit WHERE organization_unit_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "ORG_UPDATE|${id}|OrgA|DEPT|||admin@test.com")"
assert_match "ORG_UPDATE ok" "$upd_out" "SUCCESS\\|ORG_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM organization_unit WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM organization_unit_audit WHERE organization_unit_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "ORG_UPDATE|999999|OrgA|DEPT|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "ORG_UPDATE|${id}|OrgA|DEPT|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0