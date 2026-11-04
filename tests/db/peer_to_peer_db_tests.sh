#!/usr/bin/env bash
# Peer to peer (Wave16) end-to-end DB tests via the COBOL binary.
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
db_reset_peer_to_peer

# Create a cost center.
create_out="$(run_cobol "P2P_CREATE|P2P-W16-1|LenderA|CONSUMER|||admin@test.com")"
assert_match "P2P_CREATE ok" "$create_out" "SUCCESS\|P2P_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM peer_to_peer WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "P2P_CREATE|P2P-W16-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "P2P_GET ok" "$(run_cobol "P2P_GET|${id}|||||admin@test.com")" "SUCCESS\|P2P_GET\|${id}\|P2P-W16-1"
assert_match "P2P_LIST ok" "$(run_cobol "P2P_LIST|||50|0||admin@test.com")" "P2P-W16-1"

# Allocate.
assert_match "P2P_CALC ok" "$(run_cobol "P2P_CALC|${id}|||||admin@test.com")" "SUCCESS\|P2P_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM peer_to_peer WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "P2P_DELETE ok" "$(run_cobol "P2P_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|P2P_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM peer_to_peer WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "P2P_SUMMARY ok" "$(run_cobol "P2P_SUMMARY||||||admin@test.com")" "SUCCESS\|P2P_SUMMARY"
assert_match "P2P_AUDIT ok" "$(run_cobol "P2P_AUDIT|50|0||||admin@test.com")" "SUCCESS\|P2P_AUDIT"
assert_match "P2P_VALIDATE ok" "$(run_cobol "P2P_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|P2P_VALID"
assert_match "non-admin refused" "$(run_cobol "P2P_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM peer_to_peer WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM peer_to_peer_audit WHERE peer_to_peer_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "P2P_UPDATE|${id}|LenderA|CONSUMER|||admin@test.com")"
assert_match "P2P_UPDATE ok" "$upd_out" "SUCCESS\\|P2P_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM peer_to_peer WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM peer_to_peer_audit WHERE peer_to_peer_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "P2P_UPDATE|999999|LenderA|CONSUMER|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "P2P_UPDATE|${id}|LenderA|CONSUMER|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0