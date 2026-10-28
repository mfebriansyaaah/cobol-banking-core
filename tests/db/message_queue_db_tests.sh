#!/usr/bin/env bash
# Message queue (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_message_queue

# Create a cost center.
create_out="$(run_cobol "MQQ_CREATE|MQQ-W11-1|QueueA|RABBITMQ|||admin@test.com")"
assert_match "MQQ_CREATE ok" "$create_out" "SUCCESS\|MQQ_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM message_queue WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MQQ_CREATE|MQQ-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MQQ_GET ok" "$(run_cobol "MQQ_GET|${id}|||||admin@test.com")" "SUCCESS\|MQQ_GET\|${id}\|MQQ-W11-1"
assert_match "MQQ_LIST ok" "$(run_cobol "MQQ_LIST|||50|0||admin@test.com")" "MQQ-W11-1"

# Allocate.
assert_match "MQQ_CALC ok" "$(run_cobol "MQQ_CALC|${id}|||||admin@test.com")" "SUCCESS\|MQQ_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM message_queue WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MQQ_DELETE ok" "$(run_cobol "MQQ_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MQQ_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM message_queue WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "MQQ_SUMMARY ok" "$(run_cobol "MQQ_SUMMARY||||||admin@test.com")" "SUCCESS\|MQQ_SUMMARY"
assert_match "MQQ_AUDIT ok" "$(run_cobol "MQQ_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MQQ_AUDIT"
assert_match "MQQ_VALIDATE ok" "$(run_cobol "MQQ_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MQQ_VALID"
assert_match "non-admin refused" "$(run_cobol "MQQ_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0