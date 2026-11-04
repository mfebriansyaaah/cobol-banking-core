#!/usr/bin/env bash
# Notification template (Wave3) end-to-end DB tests via the COBOL binary.
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
db_reset_ntf_template_config

# Create a cost center.
create_out="$(run_cobol "NTP_CREATE|NTP-W3-1|TemplateA|EMAIL|||admin@test.com")"
assert_match "NTP_CREATE ok" "$create_out" "SUCCESS\|NTP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM ntf_template_config WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "NTP_CREATE|NTP-W3-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "NTP_GET ok" "$(run_cobol "NTP_GET|${id}|||||admin@test.com")" "SUCCESS\|NTP_GET\|${id}\|NTP-W3-1"
assert_match "NTP_LIST ok" "$(run_cobol "NTP_LIST|||50|0||admin@test.com")" "NTP-W3-1"

# Allocate.
assert_match "NTP_CALC ok" "$(run_cobol "NTP_CALC|${id}|||||admin@test.com")" "SUCCESS\|NTP_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT sent_count FROM ntf_template_config WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "NTP_DELETE ok" "$(run_cobol "NTP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|NTP_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM ntf_template_config WHERE id=${id};")" "^INACTIVE$"

# Summary and audit.
assert_match "NTP_SUMMARY ok" "$(run_cobol "NTP_SUMMARY||||||admin@test.com")" "SUCCESS\|NTP_SUMMARY"
assert_match "NTP_AUDIT ok" "$(run_cobol "NTP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|NTP_AUDIT"
assert_match "NTP_VALIDATE ok" "$(run_cobol "NTP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|NTP_VALID"
assert_match "non-admin refused" "$(run_cobol "NTP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM ntf_template_config WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM ntf_template_config_audit WHERE ntf_template_config_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "NTP_UPDATE|${id}|TemplateA|EMAIL|||admin@test.com")"
assert_match "NTP_UPDATE ok" "$upd_out" "SUCCESS\\|NTP_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM ntf_template_config WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM ntf_template_config_audit WHERE ntf_template_config_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "NTP_UPDATE|999999|TemplateA|EMAIL|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "NTP_UPDATE|${id}|TemplateA|EMAIL|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0