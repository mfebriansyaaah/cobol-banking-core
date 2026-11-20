#!/usr/bin/env bash
# Account lifecycle DB tests via the COBOL binary.
# Domain actions: ACTIVATE (OPEN->ACTIVE), FREEZE (ACTIVE->FROZEN),
# UNFREEZE (FROZEN->ACTIVE), CLOSE (zero-balance + reason -> CLOSED).
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
db_reset_account

# Create.
create_out="$(run_cobol "ACC_CREATE|ACC-W1-1|John Doe|SAVINGS|||admin@test.com")"
assert_match "ACC_CREATE ok" "$create_out" "SUCCESS\|ACC_CREATE\|[0-9]+"
assert_match "create non-admin refused" "$(run_cobol "ACC_CREATE|ACC-P10-1|John Doe|SAVINGS|||sender@test.com")" "ERROR\|FORBIDDEN"
assert_match "create missing ref" "$(run_cobol "ACC_CREATE||||||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "create bad type" "$(run_cobol "ACC_CREATE|ACC-W1-X|John Doe|CRYPTO|||admin@test.com")" "ERROR\|INVALID_TYPE"
assert_match "create missing type" "$(run_cobol "ACC_CREATE|ACC-W1-Y|John Doe||||admin@test.com")" "ERROR\|INVALID_TYPE"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM account WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ACC_CREATE|ACC-W1-1|Other|SAVINGS|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ACC_GET ok" "$(run_cobol "ACC_GET|${id}|||||admin@test.com")" "SUCCESS\|ACC_GET\|${id}\|ACC-W1-1"
assert_match "ACC_LIST ok" "$(run_cobol "ACC_LIST|||50|0||admin@test.com")" "ACC-W1-1"

# Activate: OPEN -> ACTIVE only.
assert_match "ACC_ACTIVATE ok" "$(run_cobol "ACC_ACTIVATE|${id}|||||admin@test.com")" "SUCCESS\|ACC_ACTIVATE\|${id}"
assert_match "activated persisted" "$(db_query "SELECT status FROM account WHERE id=${id};")" "^ACTIVE$"
assert_match "activate twice rejected" "$(run_cobol "ACC_ACTIVATE|${id}|||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "activate missing id" "$(run_cobol "ACC_ACTIVATE|999999|||||admin@test.com")" "ERROR\|NOT_FOUND"
assert_match "activate non-admin refused" "$(run_cobol "ACC_ACTIVATE|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

# Freeze: ACTIVE -> FROZEN only.
assert_match "ACC_FREEZE ok" "$(run_cobol "ACC_FREEZE|${id}|||||admin@test.com")" "SUCCESS\|ACC_FREEZE\|${id}"
assert_match "frozen persisted" "$(db_query "SELECT status FROM account WHERE id=${id};")" "^FROZEN$"
assert_match "freeze twice rejected" "$(run_cobol "ACC_FREEZE|${id}|||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "freeze non-admin refused" "$(run_cobol "ACC_FREEZE|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

# Freeze from OPEN rejected (fresh account).
fresh_out="$(run_cobol "ACC_CREATE|ACC-W1-2|Jane Doe|CURRENT|||admin@test.com")"
fresh_id="$(printf '%s' "$fresh_out" | awk -F'|' '{print $3}')"
assert_match "freeze from OPEN rejected" "$(run_cobol "ACC_FREEZE|${fresh_id}|||||admin@test.com")" "ERROR\|INVALID_STATUS"

# Unfreeze: FROZEN -> ACTIVE only.
assert_match "ACC_UNFREEZE ok" "$(run_cobol "ACC_UNFREEZE|${id}|||||admin@test.com")" "SUCCESS\|ACC_UNFREEZE\|${id}"
assert_match "unfrozen persisted" "$(db_query "SELECT status FROM account WHERE id=${id};")" "^ACTIVE$"
assert_match "unfreeze when ACTIVE rejected" "$(run_cobol "ACC_UNFREEZE|${id}|||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "unfreeze non-admin refused" "$(run_cobol "ACC_UNFREEZE|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

# Close: zero balance + reason required.
assert_match "close missing reason" "$(run_cobol "ACC_CLOSE|${id}|||||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "close non-admin refused" "$(run_cobol "ACC_CLOSE|${id}|Closed||||sender@test.com")" "ERROR\|FORBIDDEN"
close_out="$(run_cobol "ACC_CLOSE|${id}|Closed||||admin@test.com")"
assert_match "ACC_CLOSE ok" "$close_out" "SUCCESS\|ACC_CLOSE\|${id}"
assert_match "closed persisted" "$(db_query "SELECT status FROM account WHERE id=${id};")" "^CLOSED$"
assert_match "close reason persisted" "$(db_query "SELECT close_reason FROM account WHERE id=${id};")" "^Closed$"
assert_match "close audited" "$(db_query "SELECT COUNT(*) FROM account_audit WHERE account_id=${id} AND action='CLOSE';")" "^1$"
assert_match "activate after close rejected" "$(run_cobol "ACC_ACTIVATE|${id}|||||admin@test.com")" "ERROR\|INVALID_STATUS"

# Close blocked by non-zero balance.
bal_out="$(run_cobol "ACC_CREATE|ACC-W1-3|Bob|SAVINGS|||admin@test.com")"
bal_id="$(printf '%s' "$bal_out" | awk -F'|' '{print $3}')"
run_cobol "ACC_ACTIVATE|${bal_id}|||||admin@test.com" > /dev/null
db_exec "UPDATE account SET balance=100.0000 WHERE id=${bal_id};"
assert_match "close with balance rejected" "$(run_cobol "ACC_CLOSE|${bal_id}|Closed||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "balance close keeps status" "$(db_query "SELECT status FROM account WHERE id=${bal_id};")" "^ACTIVE$"

# Summary and audit.
assert_match "ACC_SUMMARY ok" "$(run_cobol "ACC_SUMMARY||||||admin@test.com")" "SUCCESS\|ACC_SUMMARY"
assert_match "ACC_AUDIT ok" "$(run_cobol "ACC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ACC_AUDIT"
assert_match "ACC_VALIDATE ok" "$(run_cobol "ACC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ACC_VALID"
assert_match "non-admin refused" "$(run_cobol "ACC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM account WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM account_audit WHERE account_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "ACC_UPDATE|${id}|John Doe|SAVINGS|||admin@test.com")"
assert_match "ACC_UPDATE ok" "$upd_out" "SUCCESS\\|ACC_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM account WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM account_audit WHERE account_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update bad type" "$(run_cobol "ACC_UPDATE|${id}|John Doe|CRYPTO|||admin@test.com")" "ERROR\\|INVALID_TYPE"
assert_match "update missing id" "$(run_cobol "ACC_UPDATE|999999|John Doe|SAVINGS|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "ACC_UPDATE|${id}|John Doe|SAVINGS|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
