#!/usr/bin/env bash
# SLA management (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_sla_management

# Create a cost center.
create_out="$(run_cobol "SLV_CREATE|SLV-W10-1|ServiceA|UPTIME|||admin@test.com")"
assert_match "SLV_CREATE ok" "$create_out" "SUCCESS\|SLV_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM sla_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SLV_CREATE|SLV-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SLV_GET ok" "$(run_cobol "SLV_GET|${id}|||||admin@test.com")" "SUCCESS\|SLV_GET\|${id}\|SLV-W10-1"
assert_match "SLV_LIST ok" "$(run_cobol "SLV_LIST|||50|0||admin@test.com")" "SLV-W10-1"

# Allocate.
assert_match "SLV_CALC ok" "$(run_cobol "SLV_CALC|${id}|||||admin@test.com")" "SUCCESS\|SLV_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM sla_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SLV_DELETE ok" "$(run_cobol "SLV_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SLV_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM sla_management WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "SLV_SUMMARY ok" "$(run_cobol "SLV_SUMMARY||||||admin@test.com")" "SUCCESS\|SLV_SUMMARY"
assert_match "SLV_AUDIT ok" "$(run_cobol "SLV_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SLV_AUDIT"
assert_match "SLV_VALIDATE ok" "$(run_cobol "SLV_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SLV_VALID"
assert_match "non-admin refused" "$(run_cobol "SLV_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM sla_management WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM sla_management_audit WHERE sla_management_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "SLV_UPDATE|${id}|ServiceA|UPTIME|||admin@test.com")"
assert_match "SLV_UPDATE ok" "$upd_out" "SUCCESS\\|SLV_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM sla_management WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM sla_management_audit WHERE sla_management_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "SLV_UPDATE|999999|ServiceA|UPTIME|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "SLV_UPDATE|${id}|ServiceA|UPTIME|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0