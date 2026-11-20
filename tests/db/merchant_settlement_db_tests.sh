#!/usr/bin/env bash
# Merchant settlement DB tests via the COBOL binary.
# Generic CREATE/DELETE removed (PR-2d); OPEN is the creation path and
# CANCEL the terminal path. Full calc/post/settle lifecycle lives in
# merchant_settlement_domain_db_tests.sh.
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
db_reset_merchant
db_reset_merchant_settlement
db_exec "DELETE FROM customer WHERE customer_ref='CUST-MCHD';"
db_exec "INSERT INTO customer (customer_ref, full_name, customer_type, credit_limit, used_credit, status, kyc_status, created_by) VALUES ('CUST-MCHD','PT D','CORPORATE',1000000,0,'ONBOARDED','APPROVED','admin@test.com');"

PERIOD_START="$(date +%Y-%m-01)"
PERIOD_END="$(date -d "$PERIOD_START +1 month -1 day" +%F)"

out="$(run_cobol "MRT_CREATE|MCH-D1|Toko D|RETAIL|||admin@test.com")"
mid="$(printf '%s' "$out" | awk -F'|' '{print $3}')"
db_exec "UPDATE merchant SET customer_ref='CUST-MCHD' WHERE id=${mid};"
run_cobol "MRT_SUBMIT_KYC|${mid}|||||admin@test.com" >/dev/null
run_cobol "MRT_APPROVE|${mid}|MEDIUM|2.50|1000|IDR|admin@test.com" >/dev/null
acc="$(db_query "SELECT account_id FROM accounts LIMIT 1;")"
run_cobol "MRT_ACTIVATE|${mid}|${acc}||||admin@test.com" >/dev/null
assert_match "merchant active" "$(db_query "SELECT status FROM merchant WHERE id=${mid};")" "^ACTIVE$"

# OPEN is the only creation path now.
open_out="$(run_cobol "MCS_OPEN|${mid}|MCS-D1|${PERIOD_START}|${PERIOD_END}|IDR|admin@test.com")"
assert_match "MCS_OPEN ok" "$open_out" "SUCCESS\|MCS_OPEN\|[0-9]+"
id="$(printf '%s' "$open_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM merchant_settlement WHERE id=${id};")" "^OPEN$"
assert_match "period persisted" "$(db_query "SELECT period_start FROM merchant_settlement WHERE id=${id};")" "^${PERIOD_START}$"

# OPEN guards.
assert_match "duplicate ref" "$(run_cobol "MCS_OPEN|${mid}|MCS-D1|${PERIOD_START}|${PERIOD_END}|IDR|admin@test.com")" "ERROR\|DUPLICATE"
assert_match "open missing ref" "$(run_cobol "MCS_OPEN|${mid}|||||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "open unknown merchant" "$(run_cobol "MCS_OPEN|999999|MCS-DX|${PERIOD_START}|${PERIOD_END}|IDR|admin@test.com")" "ERROR\|NOT_FOUND"
assert_match "open non-admin refused" "$(run_cobol "MCS_OPEN|${mid}|MCS-DY|${PERIOD_START}|${PERIOD_END}|IDR|sender@test.com")" "ERROR\|FORBIDDEN"

# Inactive merchant cannot open a batch.
run_cobol "MRT_SUSPEND|${mid}|||||admin@test.com" >/dev/null
assert_match "open while suspended" "$(run_cobol "MCS_OPEN|${mid}|MCS-DS|${PERIOD_START}|${PERIOD_END}|IDR|admin@test.com")" "ERROR\|INVALID_STATE"
db_exec "UPDATE merchant SET status='ACTIVE', version=version+1 WHERE id=${mid};"

# Read paths.
assert_match "MCS_GET ok" "$(run_cobol "MCS_GET|${id}|||||admin@test.com")" "SUCCESS\|MCS_GET\|${id}\|MCS-D1"
assert_match "MCS_LIST ok" "$(run_cobol "MCS_LIST|||50|0||admin@test.com")" "MCS-D1"
assert_match "non-admin read refused" "$(run_cobol "MCS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

# UPDATE (optimistic locking + audit).
ver_before="$(db_query "SELECT version FROM merchant_settlement WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM merchant_settlement_audit WHERE merchant_settlement_id=${id} AND action='UPDATE';")"
assert_match "MCS_UPDATE ok" "$(run_cobol "MCS_UPDATE|${id}|Toko D2|DAILY|||admin@test.com")" "SUCCESS\|MCS_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM merchant_settlement WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM merchant_settlement_audit WHERE merchant_settlement_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "MCS_UPDATE|999999|X|DAILY|||admin@test.com")" "ERROR\|NOT_FOUND"
assert_match "update non-admin refused" "$(run_cobol "MCS_UPDATE|${id}|X|DAILY|||sender@test.com")" "ERROR\|FORBIDDEN"

# CANCEL replaces DELETE: OPEN -> CANCELLED, terminal.
assert_match "cancel missing id" "$(run_cobol "MCS_CANCEL||||||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "MCS_CANCEL ok" "$(run_cobol "MCS_CANCEL|${id}|merchant request||||admin@test.com")" "SUCCESS\|MCS_CANCEL"
assert_match "cancelled persisted" "$(db_query "SELECT status FROM merchant_settlement WHERE id=${id};")" "^CANCELLED$"
assert_match "cancel audited" "$(db_query "SELECT COUNT(*) FROM merchant_settlement_audit WHERE merchant_settlement_id=${id} AND action='CANCEL';")" "^1$"
assert_match "cancel twice rejected" "$(run_cobol "MCS_CANCEL|${id}|again||||admin@test.com")" "ERROR\|INVALID_STATE"
assert_match "cancel non-admin refused" "$(run_cobol "MCS_CANCEL|${id}|x||||sender@test.com")" "ERROR\|FORBIDDEN"

# Summary and audit.
assert_match "MCS_SUMMARY ok" "$(run_cobol "MCS_SUMMARY||||||admin@test.com")" "SUCCESS\|MCS_SUMMARY"
assert_match "MCS_AUDIT ok" "$(run_cobol "MCS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MCS_AUDIT"
assert_match "MCS_VALIDATE ok" "$(run_cobol "MCS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MCS_VALID"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
