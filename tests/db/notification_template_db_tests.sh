#!/usr/bin/env bash
# Notification template lifecycle DB tests via the COBOL binary.
# Domain actions: PREVIEW (rendered sample), VERSION (publish/increment),
# DEACTIVATE (reason required -> INACTIVE).
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
db_reset_notification_template

# Create with valid channel.
create_out="$(run_cobol "NTP_CREATE|NTP-W4-1|Welcome|PUSH|||admin@test.com")"
assert_match "NTP_CREATE ok" "$create_out" "SUCCESS\|NTP_CREATE\|[0-9]+"
assert_match "create non-admin refused" "$(run_cobol "NTP_CREATE|NTP-P10-1|Welcome|PUSH|||sender@test.com")" "ERROR\|FORBIDDEN"
assert_match "create missing ref" "$(run_cobol "NTP_CREATE||||||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "create bad channel" "$(run_cobol "NTP_CREATE|NTP-W4-X|Welcome|PAGER|||admin@test.com")" "ERROR\|INVALID_TYPE"
assert_match "create missing channel" "$(run_cobol "NTP_CREATE|NTP-W4-Y|Welcome||||admin@test.com")" "ERROR\|INVALID_TYPE"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM ntf_template_config WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "NTP_CREATE|NTP-W4-1|Other|SMS|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "NTP_GET ok" "$(run_cobol "NTP_GET|${id}|||||admin@test.com")" "SUCCESS\|NTP_GET\|${id}\|NTP-W4-1"
assert_match "NTP_LIST ok" "$(run_cobol "NTP_LIST|||50|0||admin@test.com")" "NTP-W4-1"

# Preview: deterministic sample from stored columns.
assert_match "NTP_PREVIEW ok" "$(run_cobol "NTP_PREVIEW|${id}|||||admin@test.com")" "SUCCESS\|NTP_PREVIEW\|\[PUSH\] Welcome"
assert_match "preview missing id" "$(run_cobol "NTP_PREVIEW|999999|||||admin@test.com")" "ERROR\|NOT_FOUND"
assert_match "preview non-admin refused" "$(run_cobol "NTP_PREVIEW|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

# Version: OPEN publishes, ACTIVE increments, INACTIVE rejected.
assert_match "NTP_VERSION publishes draft" "$(run_cobol "NTP_VERSION|${id}|||||admin@test.com")" "SUCCESS\|NTP_VERSION\|${id}"
assert_match "published persisted" "$(db_query "SELECT status FROM ntf_template_config WHERE id=${id};")" "^ACTIVE$"
assert_match "version bumped" "$(db_query "SELECT version FROM ntf_template_config WHERE id=${id};")" "^2$"
assert_match "NTP_VERSION increments" "$(run_cobol "NTP_VERSION|${id}|||||admin@test.com")" "SUCCESS\|NTP_VERSION\|${id}"
assert_match "version incremented" "$(db_query "SELECT version FROM ntf_template_config WHERE id=${id};")" "^3$"
assert_match "version audited" "$(db_query "SELECT COUNT(*) FROM ntf_template_config_audit WHERE ntf_template_config_id=${id} AND action='VERSION';")" "^2$"
assert_match "version non-admin refused" "$(run_cobol "NTP_VERSION|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

# Deactivate: reason required, terminal.
assert_match "deactivate missing reason" "$(run_cobol "NTP_DEACTIVATE|${id}|||||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "NTP_DEACTIVATE ok" "$(run_cobol "NTP_DEACTIVATE|${id}|superseded||||admin@test.com")" "SUCCESS\|NTP_DEACTIVATE\|${id}"
assert_match "deactivated persisted" "$(db_query "SELECT status FROM ntf_template_config WHERE id=${id};")" "^INACTIVE$"
assert_match "deactivate audited" "$(db_query "SELECT COUNT(*) FROM ntf_template_config_audit WHERE ntf_template_config_id=${id} AND action='DEACTIVATE';")" "^1$"
assert_match "version on INACTIVE rejected" "$(run_cobol "NTP_VERSION|${id}|||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "deactivate twice rejected" "$(run_cobol "NTP_DEACTIVATE|${id}|again||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "deactivate non-admin refused" "$(run_cobol "NTP_DEACTIVATE|${id}|x||||sender@test.com")" "ERROR\|FORBIDDEN"

# Summary and audit.
assert_match "NTP_SUMMARY ok" "$(run_cobol "NTP_SUMMARY||||||admin@test.com")" "SUCCESS\|NTP_SUMMARY"
assert_match "NTP_AUDIT ok" "$(run_cobol "NTP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|NTP_AUDIT"
assert_match "NTP_VALIDATE ok" "$(run_cobol "NTP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|NTP_VALID"
assert_match "non-admin refused" "$(run_cobol "NTP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM ntf_template_config WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM ntf_template_config_audit WHERE ntf_template_config_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "NTP_UPDATE|${id}|Welcome v2|PUSH|||admin@test.com")"
assert_match "NTP_UPDATE ok" "$upd_out" "SUCCESS\\|NTP_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM ntf_template_config WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM ntf_template_config_audit WHERE ntf_template_config_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update bad channel" "$(run_cobol "NTP_UPDATE|${id}|Welcome|PAGER|||admin@test.com")" "ERROR\\|INVALID_TYPE"
assert_match "update missing id" "$(run_cobol "NTP_UPDATE|999999|Welcome|PUSH|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "NTP_UPDATE|${id}|Welcome|PUSH|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
