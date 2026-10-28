#!/usr/bin/env bash
# D3 (cards) end-to-end DB tests via the COBOL binary.
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
db_reset_card

# Issue a credit card for the seeded admin customer.
issue_out="$(run_cobol "CARD_ISSUE|CARD-T1|admin@test.com|CREDIT|5000.00|USD|admin@test.com")"
assert_match "CARD_ISSUE ok" "$issue_out" "SUCCESS\|CARD_ISSUE\|[0-9]+"
card_id="$(printf '%s' "$issue_out" | awk -F'|' '{print $3}')"
assert_match "card id present" "$card_id" "^[0-9]+$"

got="$(db_query "SELECT CONCAT(masked_pan IS NOT NULL, '|', expiry_date = DATE_ADD(CURDATE(), INTERVAL 3 YEAR), '|', available_limit, '|', balance) FROM card_account WHERE id=${card_id};")"
assert_match "masked pan, expiry, limits" "$got" "^1\|1\|5000.0000\|0.0000$"

dup_out="$(run_cobol "CARD_ISSUE|CARD-T1|admin@test.com|CREDIT|5000.00|USD|admin@test.com")"
assert_match "duplicate card ref rejected" "$dup_out" "ERROR\|DUPLICATE"

get_out="$(run_cobol "CARD_GET|${card_id}|||||admin@test.com")"
assert_match "CARD_GET ok" "$get_out" "SUCCESS\|CARD\|${card_id}"
assert_match "GET carries masked pan" "$get_out" "\*\*\*\* \*\*\*\* \*\*\*\*"

# Authorize 100: the hold reduces the available limit.
auth_out="$(run_cobol "CARD_AUTHORIZE|${card_id}|100.00|Shop A|USD||admin@test.com")"
assert_match "CARD_AUTHORIZE ok" "$auth_out" "SUCCESS\|CARD_AUTHORIZE\|AUTH-"
auth_ref="$(printf '%s' "$auth_out" | awk -F'|' '{print $3}')"
avail="$(db_query "SELECT available_limit FROM card_account WHERE id=${card_id};")"
assert_match "available reduced by hold" "$avail" "^4900.0000$"

# Over-limit and currency-mismatch authorizations are refused.
over="$(run_cobol "CARD_AUTHORIZE|${card_id}|6000.00|Shop B|USD||admin@test.com")"
assert_match "over limit rejected" "$over" "ERROR\|LIMIT_EXCEEDED"
mismatch="$(run_cobol "CARD_AUTHORIZE|${card_id}|10.00|Shop C|EUR||admin@test.com")"
assert_match "card currency enforced" "$mismatch" "ERROR\|CURRENCY_MISMATCH"

# Capture the authorization: the amount becomes outstanding balance.
cap_out="$(run_cobol "CARD_CAPTURE|${card_id}|${auth_ref}||||admin@test.com")"
assert_match "CARD_CAPTURE ok" "$cap_out" "SUCCESS\|CARD_CAPTURE\|100.0000"
bal="$(db_query "SELECT balance FROM card_account WHERE id=${card_id};")"
assert_match "balance after capture" "$bal" "^100.0000$"
txst="$(db_query "SELECT status FROM card_transaction WHERE auth_ref='${auth_ref}';")"
assert_match "authorization captured" "$txst" "^CAPTURED$"

# Reversing the capture credits the balance back and releases the limit.
rev_out="$(run_cobol "CARD_REVERSE|${card_id}|${auth_ref}||||admin@test.com")"
assert_match "CARD_REVERSE capture ok" "$rev_out" "SUCCESS\|CARD_REVERSE\|100.0000"
bal="$(db_query "SELECT CONCAT(balance, '|', available_limit) FROM card_account WHERE id=${card_id};")"
assert_match "balance and limit restored" "$bal" "^0.0000\|5000.0000$"

# Reversing a fresh authorization only releases the hold.
auth2="$(run_cobol "CARD_AUTHORIZE|${card_id}|200.00|Shop D|USD||admin@test.com")"
auth2_ref="$(printf '%s' "$auth2" | awk -F'|' '{print $3}')"
run_cobol "CARD_REVERSE|${card_id}|${auth2_ref}||||admin@test.com" >/dev/null
avail="$(db_query "SELECT available_limit FROM card_account WHERE id=${card_id};")"
assert_match "authorization hold released" "$avail" "^5000.0000$"

# Capture 300, then repay 100.
auth3="$(run_cobol "CARD_AUTHORIZE|${card_id}|300.00|Shop E|USD||admin@test.com")"
auth3_ref="$(printf '%s' "$auth3" | awk -F'|' '{print $3}')"
run_cobol "CARD_CAPTURE|${card_id}|${auth3_ref}||||admin@test.com" >/dev/null
repay="$(run_cobol "CARD_REPAY|${card_id}|100.00||||admin@test.com")"
assert_match "CARD_REPAY ok" "$repay" "SUCCESS\|CARD_REPAY\|100.00"
bal="$(db_query "SELECT CONCAT(balance, '|', available_limit) FROM card_account WHERE id=${card_id};")"
assert_match "repayment reduces balance" "$bal" "^200.0000\|4800.0000$"

# Limit cannot sit below the outstanding balance.
low="$(run_cobol "CARD_LIMIT_SET|${card_id}|100.00||||admin@test.com")"
assert_match "limit below balance rejected" "$low" "ERROR\|INVALID_AMOUNT"
set_out="$(run_cobol "CARD_LIMIT_SET|${card_id}|1000.00||||admin@test.com")"
assert_match "CARD_LIMIT_SET ok" "$set_out" "SUCCESS\|CARD_LIMIT\|1000.00"
lim="$(db_query "SELECT CONCAT(limit_amount, '|', available_limit) FROM card_account WHERE id=${card_id};")"
assert_match "limit and available updated" "$lim" "^1000.0000\|800.0000$"

# Statement lists the capture and repayment rows.
stmt="$(run_cobol "CARD_STATEMENT|${card_id}|50|0|||admin@test.com")"
assert_match "CARD_STATEMENT ok" "$stmt" "SUCCESS\|CARD_STATEMENT\|200.0000\|1000.0000\|800.0000"
assert_match "statement has repayment" "$stmt" "REPAYMENT"
assert_match "statement has capture" "$stmt" "CAPTURE"

# Replace: new card copies the balance; the old card is closed and linked.
rep_out="$(run_cobol "CARD_REPLACE|${card_id}|CARD-T2||||admin@test.com")"
assert_match "CARD_REPLACE ok" "$rep_out" "SUCCESS\|CARD_REPLACE\|[0-9]+"
new_id="$(printf '%s' "$rep_out" | awk -F'|' '{print $3}')"
old="$(db_query "SELECT CONCAT(status, '|', replaced_by) FROM card_account WHERE id=${card_id};")"
assert_match "old card closed and linked" "$old" "^CLOSED\|${new_id}$"
newbal="$(db_query "SELECT CONCAT(balance, '|', available_limit) FROM card_account WHERE id=${new_id};")"
assert_match "replacement copies balance" "$newbal" "^200.0000\|800.0000$"

# Block/unblock on the replacement.
assert_match "block replacement" "$(run_cobol "CARD_BLOCK|${new_id}|||||admin@test.com")" "SUCCESS\|CARD_BLOCKED"
assert_match "unblock replacement" "$(run_cobol "CARD_UNBLOCK|${new_id}|||||admin@test.com")" "SUCCESS\|CARD_UNBLOCKED"

# Summary counts both cards (one closed, one active).
sum="$(run_cobol "CARD_SUMMARY||||||admin@test.com")"
assert_match "CARD_SUMMARY ok" "$sum" "SUCCESS\|CARD_SUMMARY\|2\|1\|0\|1"

# Audit trail exists for the lifecycle.
ac="$(db_query "SELECT COUNT(*) FROM card_audit WHERE card_id=${card_id};")"
assert_match "audit rows recorded" "$ac" "^[1-9][0-9]*$"
aud="$(run_cobol "CARD_AUDIT|${card_id}|50|0|||admin@test.com")"
assert_match "CARD_AUDIT ok" "$aud" "SUCCESS\|CARD_AUDIT\|"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
