#!/usr/bin/env bash
# Fixed Asset schema/constraint tests (PR-701).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
require_db

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

# Registry with domain columns.
db_exec "DELETE FROM fixed_asset WHERE asset_ref='FA-S1';"
db_exec "INSERT INTO fixed_asset (asset_ref, asset_name, asset_type, asset_category, acquisition_date, acquisition_cost, residual_value, useful_life_months, depreciation_method, net_book_value, cost_center, status, created_by) VALUES ('FA-S1','Gedung','BUILDING','BUILDING','2026-01-15',12000000,2000000,120,'STRAIGHT_LINE',12000000,'CC-01','ACTIVE','admin@test.com');"
AID="$(db_query "SELECT id FROM fixed_asset WHERE asset_ref='FA-S1';")"
assert_match "asset inserted" "$AID" "^[0-9]+$"
assert_match "nbv stored" "$(db_query "SELECT net_book_value FROM fixed_asset WHERE id=${AID};")" "^12000000"
assert_match "ref unique" "$(db_query "SELECT COUNT(*) FROM fixed_asset WHERE asset_ref='FA-S1';")" "^1$"
db_exec "INSERT INTO fixed_asset (asset_ref, asset_name, asset_type, asset_category, acquisition_cost, created_by) VALUES ('FA-S1','X','OTHER','OTHER',1,'admin@test.com');" 2>/dev/null
assert_match "ref unique enforced" "$(db_query "SELECT COUNT(*) FROM fixed_asset WHERE asset_ref='FA-S1';")" "^1$"

# Depreciation: one row per asset+period, non-negative.
db_exec "INSERT INTO fixed_asset_depreciation (asset_id, period, depreciation_amount, accumulated_after, created_by) VALUES (${AID}, '2026-10', 83333.3333, 83333.3333, 'admin@test.com');"
assert_match "depreciation row" "$(db_query "SELECT COUNT(*) FROM fixed_asset_depreciation WHERE asset_id=${AID};")" "^1$"
db_exec "INSERT INTO fixed_asset_depreciation (asset_id, period, depreciation_amount, accumulated_after, created_by) VALUES (${AID}, '2026-10', 1, 1, 'admin@test.com');" 2>/dev/null
assert_match "period unique" "$(db_query "SELECT COUNT(*) FROM fixed_asset_depreciation WHERE asset_id=${AID};")" "^1$"
db_exec "INSERT INTO fixed_asset_depreciation (asset_id, period, depreciation_amount, accumulated_after, created_by) VALUES (${AID}, '2026-11', -1, 0, 'admin@test.com');" 2>/dev/null
assert_match "amount check" "$(db_query "SELECT COUNT(*) FROM fixed_asset_depreciation WHERE asset_id=${AID} AND period='2026-11';")" "^0$"

# Disposal with proceeds >= 0.
db_exec "INSERT INTO fixed_asset_disposal (asset_id, disposal_date, proceeds_amount, gain_loss_amount, reason, created_by) VALUES (${AID}, '2026-10-30', 5000000, -100000, 'lelang', 'admin@test.com');"
assert_match "disposal row" "$(db_query "SELECT COUNT(*) FROM fixed_asset_disposal WHERE asset_id=${AID};")" "^1$"

# Cleanup (children first).
db_exec "DELETE FROM fixed_asset_disposal WHERE asset_id=${AID};"
db_exec "DELETE FROM fixed_asset_depreciation WHERE asset_id=${AID};"
db_exec "DELETE FROM fixed_asset_audit WHERE asset_id=${AID};"
db_exec "DELETE FROM fixed_asset WHERE id=${AID};"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
