#!/usr/bin/env bash
# Integration: fixed asset capitalize -> depreciate -> revalue -> dispose + GL.
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
db_reset_fixed_asset
ADMIN="faint@test.com"
db_exec "INSERT INTO users (email, password_hash, full_name, dob, status, role) VALUES ('$ADMIN', CONCAT('SHA256_',SHA2('secret123',256)), 'Fa Int', '1990-01-01', 'VERIFIED', 'SUPER_ADMIN') ON DUPLICATE KEY UPDATE role='SUPER_ADMIN', status='VERIFIED';"

echo "=== Fixed asset integration (capitalize -> depreciate -> revalue -> dispose) ==="

OUT=$(run_cobol "FAS_CAPITALIZE|FA-INT-1|Gedung|BUILDING|1200000:200000:120|2026-01-15:CC-01:1500:5000:4200|$ADMIN")
assert_match "capitalize" "$OUT" "SUCCESS\|FAS_CAPITALIZE"
AID=$(printf '%s' "$OUT" | awk -F'|' '{print $3}')
assert_match "active" "$(db_query "SELECT status FROM fixed_asset WHERE id=${AID};")" "^ACTIVE$"

assert_match "depreciate" "$(run_cobol "FAS_DEPRECIATE|${AID}|2026-10||||$ADMIN")" "SUCCESS\|FAS_DEPRECIATE\|8333"
assert_match "duplicate period" "$(run_cobol "FAS_DEPRECIATE|${AID}|2026-10||||$ADMIN")" "ERROR\|DUPLICATE"

GOUT=$(run_cobol "GL_JOURNAL_POST|2026-10-30|Fixed asset FA-INT-1 depr|5000|1100|IDR:8333.3333|$ADMIN")
assert_match "gl posted" "$GOUT" "SUCCESS\|GL_POSTED"
GJ=$(db_query "SELECT id FROM gl_journal ORDER BY id DESC LIMIT 1;")
assert_match "gl balanced" "$(db_query "SELECT IF(SUM(debit_amount)=SUM(credit_amount) AND SUM(debit_amount)>0,'BALANCED','UNBALANCED') FROM gl_journal_line WHERE journal_id=${GJ};")" "^BALANCED$"

assert_match "depreciate with gl" "$(run_cobol "FAS_DEPRECIATE|${AID}|2026-11|${GJ}|||$ADMIN")" "SUCCESS\|FAS_DEPRECIATE"
assert_match "gl linked" "$(db_query "SELECT gl_journal_id FROM fixed_asset_depreciation WHERE asset_id=${AID} AND period='2026-11';")" "^${GJ}$"

assert_match "revalue" "$(run_cobol "FAS_REVALUE|${AID}|1100000|${GJ}|||$ADMIN")" "SUCCESS\|FAS_REVALUE"
assert_match "impaired" "$(db_query "SELECT status FROM fixed_asset WHERE id=${AID};")" "^IMPAIRED$"
assert_match "nbv revalued" "$(db_query "SELECT net_book_value FROM fixed_asset WHERE id=${AID};")" "^1100000"

assert_match "dispose" "$(run_cobol "FAS_DISPOSE|${AID}|900000|Jual|${GJ}||$ADMIN")" "SUCCESS\|FAS_DISPOSE\|-200000"
assert_match "disposed" "$(db_query "SELECT status FROM fixed_asset WHERE id=${AID};")" "^DISPOSED$"
assert_match "loss persisted" "$(db_query "SELECT gain_loss_amount FROM fixed_asset_disposal WHERE asset_id=${AID};")" "^-200000"
assert_match "audit rows" "$(db_query "SELECT COUNT(*) FROM fixed_asset_audit WHERE asset_id=${AID};")" "^[1-9]"

# Cleanup.
db_exec "DELETE FROM fixed_asset_audit WHERE asset_id=${AID};"
db_exec "DELETE FROM fixed_asset_disposal WHERE asset_id=${AID};"
db_exec "DELETE FROM fixed_asset_depreciation WHERE asset_id=${AID};"
db_exec "DELETE FROM fixed_asset WHERE id=${AID};"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
