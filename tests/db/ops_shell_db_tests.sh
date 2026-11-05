#!/usr/bin/env bash
# Ops shell coverage: disputes, transfers, recon, outbox, dual-control
# requests, and access reviews via run_cobol.
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
S="sender@test.com"
R="receiver@test.com"
A="admin@test.com"
db_exec "DELETE FROM dispute_cases WHERE reporter_email LIKE 'opssh%@test.com';"
db_exec "DELETE FROM access_reviews WHERE opened_by='${A}';"

# Money movement with a unique key per run (rerun-safe by construction).
U="opsshellU@test.com"
run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Ops Shell|1990-01-01" >/dev/null
ucode="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run_cobol "VERIFY_EMAIL|${U}|${ucode}" >/dev/null
KEY="OPS-$(date +%s%N)-$$"
assert_match "TRANSFER ok" "$(run_cobol "TRANSFER|${S}|${R}|10.00|${KEY}|||")" "SUCCESS\|TRANSFER"
assert_match "TX_STATUS ok" "$(run_cobol "TX_STATUS|${KEY}|${S}|")" "SUCCESS\|"
assert_match "STATEMENT ok" "$(run_cobol "STATEMENT|${S}|${S}|USD|||")" "SUCCESS\|"
assert_match "REVERSE_TRANSFER ok" "$(run_cobol "REVERSE_TRANSFER|${KEY}|${A}|${S}|CUSTOMER_ERROR")" "SUCCESS\|"
assert_match "double reverse refused" "$(run_cobol "REVERSE_TRANSFER|${KEY}|${A}|${S}|CUSTOMER_ERROR")" "ERROR\|ALREADY_REVERSED"
assert_match "GET_DASHBOARD ok" "$(run_cobol "GET_DASHBOARD|${S}|${S}")" "SUCCESS\|"

# Disputes are owner-scoped (actor must equal the owner).
D="opsshellD@test.com"
run_cobol "REQUEST_SIGNUP|${D}|Passw0rd!|Ops Dis|1992-03-03" >/dev/null
dcode="$(db_query "SELECT code FROM verification_logs WHERE email='${D}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run_cobol "VERIFY_EMAIL|${D}|${dcode}" >/dev/null
dopen="$(run_cobol "OPEN_DISPUTE|${D}|${D}|Late delivery|Item never arrived|")"
assert_match "OPEN_DISPUTE ok" "$dopen" "SUCCESS\|"
did="$(db_query "SELECT case_id FROM dispute_cases WHERE user_id=(SELECT id FROM users WHERE email='${D}') ORDER BY case_id DESC LIMIT 1;")"
assert_match "dispute row present" "$did" "^[0-9]+$"
assert_match "ADD_DISPUTE_NOTE ok" "$(run_cobol "ADD_DISPUTE_NOTE|${did}|${D}|Still waiting|")" "SUCCESS\|"
assert_match "GET_DISPUTE ok" "$(run_cobol "GET_DISPUTE|${did}|${D}")" "SUCCESS\|"
assert_match "LIST_DISPUTES ok" "$(run_cobol "LIST_DISPUTES|${A}||||")" "SUCCESS\|"
assert_match "ACK_DISPUTE ok" "$(run_cobol "ACK_DISPUTE|${did}|${A}|")" "SUCCESS\|"
assert_match "RESOLVE_DISPUTE ok" "$(run_cobol "RESOLVE_DISPUTE|${did}|${A}|Refunded")" "SUCCESS\|"
dopen2="$(run_cobol "OPEN_DISPUTE|${D}|${D}|Damaged|Broken on arrival|")"
assert_match "second OPEN_DISPUTE ok" "$dopen2" "SUCCESS\|"
did2="$(db_query "SELECT case_id FROM dispute_cases WHERE user_id=(SELECT id FROM users WHERE email='${D}') ORDER BY case_id DESC LIMIT 1;")"
assert_match "REJECT_DISPUTE ok" "$(run_cobol "REJECT_DISPUTE|${did2}|${A}|No proof")" "SUCCESS\|"

# Reconciliation + outbox reads.
assert_match "RECONCILE verdict" "$(run_cobol "RECONCILE|${A}")" "SUCCESS\\|RECONCILED|ERROR\\|MISMATCH"
assert_match "RUN_RECONCILIATION ok" "$(run_cobol "RUN_RECONCILIATION|${A}|MANUAL")" "SUCCESS\|"
assert_match "LIST_RECONCILIATIONS ok" "$(run_cobol "LIST_RECONCILIATIONS|${A}|50|0")" "SUCCESS\|"
assert_match "LIST_OUTBOX ok" "$(run_cobol "LIST_OUTBOX|${A}|||")" "SUCCESS\|"

# Exceptions: list, then ack/resolve whatever the recon run produced
# (or assert NOT_FOUND when the queue is empty — the action still runs).
assert_match "LIST_EXCEPTIONS ok" "$(run_cobol "LIST_EXCEPTIONS|${A}|||")" "SUCCESS\|"
fid="$(db_query "SELECT id FROM recon_exception WHERE state='OPEN' ORDER BY id DESC LIMIT 1;")"
if [ -n "$fid" ]; then
    assert_match "ACK_EXCEPTION ok" "$(run_cobol "ACK_EXCEPTION|${fid}|${A}")" "SUCCESS\|"
    assert_match "RESOLVE_EXCEPTION ok" "$(run_cobol "RESOLVE_EXCEPTION|${fid}|${A}|fixed")" "SUCCESS\|"
else
    assert_match "ACK_EXCEPTION missing" "$(run_cobol "ACK_EXCEPTION|999999|${A}")" "ERROR\|"
    assert_match "RESOLVE_EXCEPTION missing" "$(run_cobol "RESOLVE_EXCEPTION|999999|${A}|x")" "ERROR\|"
fi

# Dual-control operation request lifecycle (CHANGE_ROLE is executable).
# Designation list is empty by default (Gate 0): designate for this suite,
# clean up at the end. Checker must differ from the maker: second super admin.
db_exec "INSERT IGNORE INTO dual_control_operations (operation) VALUES ('CHANGE_ROLE');"
db_exec "INSERT INTO users (email, password_hash, full_name, dob, status, role) VALUES ('opschecker@test.com', 'x', 'Ops Checker', '1990-01-01', 'VERIFIED', 'SUPER_ADMIN') ON DUPLICATE KEY UPDATE role='SUPER_ADMIN';"
assert_match "REQUEST_OPERATION ok" "$(run_cobol "REQUEST_OPERATION|CHANGE_ROLE|${U}|MANAGER|${A}")" "SUCCESS\|"
reqid="$(db_query "SELECT request_id FROM maker_requests WHERE target_email='${U}' ORDER BY request_id DESC LIMIT 1;")"
assert_match "request row present" "$reqid" "^[0-9]+$"
assert_match "LIST_REQUESTS ok" "$(run_cobol "LIST_REQUESTS|${A}|||")" "SUCCESS\|"
assert_match "APPROVE_REQUEST ok" "$(run_cobol "APPROVE_REQUEST|${reqid}|opschecker@test.com")" "SUCCESS\|"
assert_match "REQUEST_OPERATION again" "$(run_cobol "REQUEST_OPERATION|CHANGE_ROLE|${U}|USER|${A}")" "SUCCESS\|"
reqid2="$(db_query "SELECT request_id FROM maker_requests WHERE target_email='${U}' ORDER BY request_id DESC LIMIT 1;")"
assert_match "REJECT_REQUEST ok" "$(run_cobol "REJECT_REQUEST|${reqid2}|opschecker@test.com")" "SUCCESS\|"

# Access review lifecycle (single OPEN review at a time; close at the end).
openrev="$(db_query "SELECT review_id FROM access_reviews WHERE state='OPEN' ORDER BY review_id DESC LIMIT 1;")"
[ -n "$openrev" ] && run_cobol "CLOSE_ACCESS_REVIEW|${A}|${openrev}" >/dev/null
assert_match "OPEN_ACCESS_REVIEW ok" "$(run_cobol "OPEN_ACCESS_REVIEW|${A}|2026-01-01|2026-12-31")" "SUCCESS\|"
revid="$(db_query "SELECT review_id FROM access_reviews WHERE state='OPEN' ORDER BY review_id DESC LIMIT 1;")"
assert_match "review row present" "$revid" "^[0-9]+$"
assert_match "LIST_ACCESS_REVIEWS ok" "$(run_cobol "LIST_ACCESS_REVIEWS|${A}|||")" "SUCCESS\|"
assert_match "GET_ACCESS_REVIEW ok" "$(run_cobol "GET_ACCESS_REVIEW|${A}|${revid}")" "SUCCESS\|"
decide_fail=0
decide_n=0
# Self-attestation is refused: the admin's own items are decided by the
# second super admin created above for dual-control checks.
for itemid in $(db_query "SELECT item_id FROM access_review_items WHERE review_id=${revid} AND decision='PENDING' AND email<>'admin@test.com';"); do
    if ! run_cobol "DECIDE_ACCESS_ITEM|${A}|${itemid}|ATTESTED|ok" | grep -q "SUCCESS|"; then
        decide_fail=$((decide_fail + 1))
    fi
    decide_n=$((decide_n + 1))
done
for itemid in $(db_query "SELECT item_id FROM access_review_items WHERE review_id=${revid} AND decision='PENDING' AND email='admin@test.com';"); do
    if ! run_cobol "DECIDE_ACCESS_ITEM|opschecker@test.com|${itemid}|ATTESTED|ok" | grep -q "SUCCESS|"; then
        decide_fail=$((decide_fail + 1))
    fi
    decide_n=$((decide_n + 1))
done
assert_match "items seen" "$decide_n" "^[1-9][0-9]*$"
assert_match "all items decided" "$decide_fail" "^0$"
assert_match "CLOSE_ACCESS_REVIEW ok" "$(run_cobol "CLOSE_ACCESS_REVIEW|${A}|${revid}")" "SUCCESS\|"
assert_match "review closed" "$(db_query "SELECT state FROM access_reviews WHERE review_id=${revid};")" "^CLOSED$"

# Role read proves the approved request executed (U is MANAGER now).
assert_match "CHECK_ROLE ok" "$(run_cobol "CHECK_ROLE|${U}|MANAGER|${A}")" "SUCCESS\|"

db_exec "DELETE FROM dispute_cases WHERE reporter_email LIKE 'opssh%@test.com';"
db_exec "DELETE FROM dispute_messages WHERE case_id NOT IN (SELECT case_id FROM dispute_cases);"
db_exec "DELETE FROM maker_requests WHERE target_email='${U}';"
db_exec "DELETE FROM dual_control_operations WHERE operation='CHANGE_ROLE';"
db_exec "DELETE FROM users WHERE email LIKE 'opsshell%@test.com' OR email LIKE 'opsshellD@test.com' OR email='opschecker@test.com';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
