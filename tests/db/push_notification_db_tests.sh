#!/usr/bin/env bash
# Push notification (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_push_notification

# Create a cost center.
create_out="$(run_cobol "PSH_CREATE|PSH-W11-1|AppA|FCM|||admin@test.com")"
assert_match "PSH_CREATE ok" "$create_out" "SUCCESS\|PSH_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM push_notification WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PSH_CREATE|PSH-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PSH_GET ok" "$(run_cobol "PSH_GET|${id}|||||admin@test.com")" "SUCCESS\|PSH_GET\|${id}\|PSH-W11-1"
assert_match "PSH_LIST ok" "$(run_cobol "PSH_LIST|||50|0||admin@test.com")" "PSH-W11-1"

# Allocate.
assert_match "PSH_CALC ok" "$(run_cobol "PSH_CALC|${id}|||||admin@test.com")" "SUCCESS\|PSH_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM push_notification WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PSH_DELETE ok" "$(run_cobol "PSH_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PSH_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM push_notification WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PSH_SUMMARY ok" "$(run_cobol "PSH_SUMMARY||||||admin@test.com")" "SUCCESS\|PSH_SUMMARY"
assert_match "PSH_AUDIT ok" "$(run_cobol "PSH_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PSH_AUDIT"
assert_match "PSH_VALIDATE ok" "$(run_cobol "PSH_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PSH_VALID"
assert_match "non-admin refused" "$(run_cobol "PSH_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM push_notification WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM push_notification_audit WHERE push_notification_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "PSH_UPDATE|${id}|AppA|FCM|||admin@test.com")"
assert_match "PSH_UPDATE ok" "$upd_out" "SUCCESS\\|PSH_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM push_notification WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM push_notification_audit WHERE push_notification_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "PSH_UPDATE|999999|AppA|FCM|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "PSH_UPDATE|${id}|AppA|FCM|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0