#!/usr/bin/env bash
# 16KB result buffer (PR-061): small lists serve fully, oversized lists fail
# loud with ERROR|RESULT_TRUNCATED (never silently cut).
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
A="admin@test.com"
AID="$(db_query "SELECT id FROM users WHERE email='${A}';")"
db_exec "DELETE FROM audit_trail WHERE action='TRUNC_PROBE';"

assert_match "small list ok" "$(run_cobol "LIST_AUDIT|${A}|||10|0|")" "SUCCESS\|"

# ~100 rows x ~350 bytes: well past the 16KB buffer. Single-VALUES
# inserts (a big UNION-SELECT silently inserts nothing on this MariaDB).
for _ in $(seq 1 100); do
    db_exec "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) VALUES (${AID}, ${AID}, 'TRUNC_PROBE', 'TEST', '1', REPEAT('0123456789ABCDEF', 15), 'SUCCESS');"
done
assert_match "seeded 100 rows" "$(db_query "SELECT COUNT(*) FROM audit_trail WHERE action='TRUNC_PROBE';")" "^100$"
big_out="$(run_cobol "LIST_AUDIT|${A}|||100|0|")"
assert_match "oversize fails loud (marker, never silent cut)" "$big_out" "ERROR\|RESULT_TRUNCATED"
assert_match "small filtered list ok" "$(run_cobol "LIST_AUDIT|${A}|||10|0|")" "SUCCESS\|"

db_exec "DELETE FROM audit_trail WHERE action='TRUNC_PROBE';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
