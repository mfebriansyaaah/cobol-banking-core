#!/usr/bin/env bash
# Fixed Asset lifecycle (PR-702): capitalize/depreciate/revalue/dispose + GL link.
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

# CAPITALIZE happy path + guards.
out="$(run_cobol "FAS_CAPITALIZE|FA-D1|Gedung|BUILDING|12000000:2000000:120|2026-01-15:CC-01:1500:5000:4200|admin@test.com")"
assert_match "capitalize ok" "$out" "SUCCESS\|FAS_CAPITALIZE\|[0-9]+"
id="$(printf '%s' "$out" | awk -F'|' '{print $3}')"
assert_match "active persisted" "$(db_query "SELECT status FROM fixed_asset WHERE id=${id};")" "^ACTIVE$"
assert_match "nbv equals cost" "$(db_query "SELECT net_book_value FROM fixed_asset WHERE id=${id};")" "^12000000"
assert_match "residual stored" "$(db_query "SELECT residual_value FROM fixed_asset WHERE id=${id};")" "^2000000"
assert_match "life stored" "$(db_query "SELECT useful_life_months FROM fixed_asset WHERE id=${id};")" "^120$"
assert_match "cost center stored" "$(db_query "SELECT cost_center FROM fixed_asset WHERE id=${id};")" "^CC-01$"
assert_match "duplicate ref" "$(run_cobol "FAS_CAPITALIZE|FA-D1|X|BUILDING|100:0:12|2026-01-15:CC-01:1500:5000:4200|admin@test.com")" "ERROR\|DUPLICATE"
assert_match "zero cost" "$(run_cobol "FAS_CAPITALIZE|FA-DX|X|BUILDING|0:0:12|2026-01-15:CC-01:1500:5000:4200|admin@test.com")" "ERROR\|INVALID_AMOUNT"
assert_match "zero life" "$(run_cobol "FAS_CAPITALIZE|FA-DX|X|BUILDING|100:0:0|2026-01-15:CC-01:1500:5000:4200|admin@test.com")" "ERROR\|INVALID_AMOUNT"
assert_match "residual >= cost" "$(run_cobol "FAS_CAPITALIZE|FA-DX|X|BUILDING|100:100:12|2026-01-15:CC-01:1500:5000:4200|admin@test.com")" "ERROR\|INVALID_AMOUNT"

# DEPRECIATE happy path + guards.
assert_match "depreciate ok" "$(run_cobol "FAS_DEPRECIATE|${id}|2026-10||||admin@test.com")" "SUCCESS\|FAS_DEPRECIATE\|83333"
assert_match "accumulated posted" "$(db_query "SELECT accumulated_depreciation FROM fixed_asset WHERE id=${id};")" "^83333"
assert_match "nbv reduced" "$(db_query "SELECT net_book_value FROM fixed_asset WHERE id=${id};")" "^11916666"
assert_match "depreciation row" "$(db_query "SELECT COUNT(*) FROM fixed_asset_depreciation WHERE asset_id=${id} AND period='2026-10';")" "^1$"
assert_match "duplicate period" "$(run_cobol "FAS_DEPRECIATE|${id}|2026-10||||admin@test.com")" "ERROR\|DUPLICATE"
assert_match "depreciate gl link" "$(run_cobol "FAS_DEPRECIATE|${id}|2026-11|777|||admin@test.com")" "SUCCESS\|FAS_DEPRECIATE"
assert_match "gl linked" "$(db_query "SELECT gl_journal_id FROM fixed_asset_depreciation WHERE asset_id=${id} AND period='2026-11';")" "^777$"
assert_match "unknown asset" "$(run_cobol "FAS_DEPRECIATE|999999999|2026-12||||admin@test.com")" "ERROR\|NOT_FOUND"
assert_match "non-admin refused" "$(run_cobol "FAS_DEPRECIATE|${id}|2026-12||||sender@test.com")" "ERROR\|FORBIDDEN"

# REVALUE down to 11M (impairment) with GL link.
assert_match "revalue ok" "$(run_cobol "FAS_REVALUE|${id}|11000000|888|||admin@test.com")" "SUCCESS\|FAS_REVALUE"
assert_match "impaired status" "$(db_query "SELECT status FROM fixed_asset WHERE id=${id};")" "^IMPAIRED$"
assert_match "accumulated adjusted" "$(db_query "SELECT accumulated_depreciation FROM fixed_asset WHERE id=${id};")" "^1000000"
assert_match "nbv revalued" "$(db_query "SELECT net_book_value FROM fixed_asset WHERE id=${id};")" "^11000000"
assert_match "revalue gl linked" "$(db_query "SELECT gl_journal_id FROM fixed_asset WHERE id=${id};")" "^888$"
assert_match "revalue above cost" "$(run_cobol "FAS_REVALUE|${id}|13000000||||admin@test.com")" "ERROR\|INVALID_(AMOUNT|STATE)"
assert_match "unknown asset" "$(run_cobol "FAS_REVALUE|999999999|100||||admin@test.com")" "ERROR\|NOT_FOUND"

# DISPOSE loss case: 5M proceeds vs 11M NBV = -6M.
assert_match "dispose ok" "$(run_cobol "FAS_DISPOSE|${id}|5000000|Lelang|999||admin@test.com")" "SUCCESS\|FAS_DISPOSE\|-6000000"
assert_match "disposed status" "$(db_query "SELECT status FROM fixed_asset WHERE id=${id};")" "^DISPOSED$"
assert_match "loss persisted" "$(db_query "SELECT gain_loss_amount FROM fixed_asset_disposal WHERE asset_id=${id};")" "^-6000000"
assert_match "dispose gl linked" "$(db_query "SELECT gl_journal_id FROM fixed_asset_disposal WHERE asset_id=${id};")" "^999$"
assert_match "dispose twice invalid" "$(run_cobol "FAS_DISPOSE|${id}|1|x|||admin@test.com")" "ERROR\|INVALID_STATE"

# DISPOSE gain case on a fresh asset.
out2="$(run_cobol "FAS_CAPITALIZE|FA-D2|Mobil|VEHICLE|100000:10000:60|2026-02-01:CC-02:1510:5010:4210|admin@test.com")"
id2="$(printf '%s' "$out2" | awk -F'|' '{print $3}')"
assert_match "dispose gain" "$(run_cobol "FAS_DISPOSE|${id2}|120000|Jual|||admin@test.com")" "SUCCESS\|FAS_DISPOSE\|20000"
assert_match "gain persisted" "$(db_query "SELECT gain_loss_amount FROM fixed_asset_disposal WHERE asset_id=${id2};")" "^20000"

assert_match "audit rows" "$(db_query "SELECT COUNT(*) FROM fixed_asset_audit WHERE asset_id IN (${id},${id2});")" "^[1-9]"
assert_match "non-admin refused" "$(run_cobol "FAS_REVALUE|${id2}|90000||||sender@test.com")" "ERROR\|FORBIDDEN"

# Cleanup.
db_exec "DELETE FROM fixed_asset_audit WHERE asset_id IN (${id},${id2});"
db_exec "DELETE FROM fixed_asset_disposal WHERE asset_id IN (${id},${id2});"
db_exec "DELETE FROM fixed_asset_depreciation WHERE asset_id IN (${id},${id2});"
db_exec "DELETE FROM fixed_asset WHERE id IN (${id},${id2});"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
