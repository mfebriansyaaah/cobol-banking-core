#!/usr/bin/env bash
# Peer lending (Wave20) end-to-end DB tests via the COBOL binary.
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
db_reset_peer_lending

# Create a cost center.
create_out="$(run_cobol "PDLG_CREATE|PDLG-W20-1|PeerA|CONSUMER|||admin@test.com")"
assert_match "PDLG_CREATE ok" "$create_out" "SUCCESS\|PDLG_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM peer_lending WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PDLG_CREATE|PDLG-W20-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PDLG_GET ok" "$(run_cobol "PDLG_GET|${id}|||||admin@test.com")" "SUCCESS\|PDLG_GET\|${id}\|PDLG-W20-1"
assert_match "PDLG_LIST ok" "$(run_cobol "PDLG_LIST|||50|0||admin@test.com")" "PDLG-W20-1"

# Allocate.
assert_match "PDLG_CALC ok" "$(run_cobol "PDLG_CALC|${id}|||||admin@test.com")" "SUCCESS\|PDLG_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM peer_lending WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PDLG_DELETE ok" "$(run_cobol "PDLG_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PDLG_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM peer_lending WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PDLG_SUMMARY ok" "$(run_cobol "PDLG_SUMMARY||||||admin@test.com")" "SUCCESS\|PDLG_SUMMARY"
assert_match "PDLG_AUDIT ok" "$(run_cobol "PDLG_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PDLG_AUDIT"
assert_match "PDLG_VALIDATE ok" "$(run_cobol "PDLG_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PDLG_VALID"
assert_match "non-admin refused" "$(run_cobol "PDLG_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM peer_lending WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM peer_lending_audit WHERE peer_lending_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "PDLG_UPDATE|${id}|PeerA|CONSUMER|||admin@test.com")"
assert_match "PDLG_UPDATE ok" "$upd_out" "SUCCESS\\|PDLG_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM peer_lending WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM peer_lending_audit WHERE peer_lending_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "PDLG_UPDATE|999999|PeerA|CONSUMER|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "PDLG_UPDATE|${id}|PeerA|CONSUMER|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0