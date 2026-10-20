#!/bin/bash
# Access review suite (ADR 0073): a SUPER_ADMIN opens a review that snapshots
# every privileged account, a reviewer other than the subject records a
# decision per item, and the review closes only once every item is decided
# and every revoked access is actually gone. The opening, the decisions, and
# the close are audited.
# Usage: ./tests/test_access_reviews.sh

BIN="./cobol/bin/main_logic"

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }

run() {
    printf "%s|%s|%s|%s|%s\n" "$1" "$2" "$3" "$4" "$5" > input.txt
    "$BIN" >/dev/null 2>&1
    cat output.txt
}

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected [$expected] got [$actual])"; failed=$((failed+1))
    fi
}

check_contains() {
    local name="$1" expected="$2" actual="$3"
    if [[ "$actual" == *"$expected"* ]]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected to contain [$expected] got [$actual])"; failed=$((failed+1))
    fi
}

A1="ar_a1@test.com"; A2="ar_a2@test.com"; M="ar_mgr@test.com"; U="ar_user@test.com"

setup() {
    q "DELETE FROM access_review_items;
       DELETE FROM access_reviews;
       DELETE FROM users WHERE email IN ('$A1','$A2','$M','$U');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1951,'$A1',CONCAT('SHA256_',SHA2('secret',256)),'AR Admin One','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1952,'$A2',CONCAT('SHA256_',SHA2('secret',256)),'AR Admin Two','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1953,'$M',CONCAT('SHA256_',SHA2('secret',256)),'AR Manager','1990-01-01','VERIFIED','MANAGER'),
       (1954,'$U',CONCAT('SHA256_',SHA2('secret',256)),'AR User','1990-01-01','VERIFIED','USER');"
}

teardown() {
    q "DELETE FROM access_review_items;
       DELETE FROM access_reviews;
       DELETE FROM audit_trail WHERE action LIKE 'ACCESS_REVIEW%';
       DELETE FROM audit_trail WHERE action = 'AUTHZ_DENIED' AND entity_id IN
         ('DECIDE_ACCESS_ITEM','OPEN_ACCESS_REVIEW','CLOSE_ACCESS_REVIEW','LIST_ACCESS_REVIEWS','GET_ACCESS_REVIEW');
       DELETE FROM users WHERE email IN ('$A1','$A2','$M','$U');"
}
trap teardown EXIT

echo "======================================================================"
echo "  ACCESS REVIEW SUITE"
echo "======================================================================"

setup

# --- opening a review ------------------------------------------------------------
check "a non-admin cannot open a review" "ERROR|FORBIDDEN" \
    "$(run OPEN_ACCESS_REVIEW "$M" 2026-10-01 2026-10-31 "")"
check "a malformed period start is refused" "ERROR|INVALID_INPUT" \
    "$(run OPEN_ACCESS_REVIEW "$A1" 2026-1-01 2026-10-31 "")"
check "a reversed period is refused" "ERROR|INVALID_INPUT" \
    "$(run OPEN_ACCESS_REVIEW "$A1" 2026-11-01 2026-10-31 "")"
OPENED="$(run OPEN_ACCESS_REVIEW "$A1" 2026-10-01 2026-10-31 "")"
check_contains "an admin opens a review" "SUCCESS|REVIEW_OPENED|" "$OPENED"
RID="$(echo "$OPENED" | cut -d'|' -f3)"

# The snapshot covers the privileged accounts of this suite and every other
# privileged account in the database, so assert on this suite's own rows.
check "the review snapshots the admins" "3" \
    "$(q "SELECT COUNT(*) FROM access_review_items WHERE review_id=$RID AND email IN ('$A1','$A2','$M');")"
check "the review leaves a plain user out" "0" \
    "$(q "SELECT COUNT(*) FROM access_review_items WHERE review_id=$RID AND email='$U';")"
check "the item records the role at open time" "MANAGER" \
    "$(q "SELECT role FROM access_review_items WHERE review_id=$RID AND email='$M';")"
check "the item records the account status" "VERIFIED" \
    "$(q "SELECT account_status FROM access_review_items WHERE review_id=$RID AND email='$M';")"
check "the item records the MFA state" "0" \
    "$(q "SELECT mfa_enabled FROM access_review_items WHERE review_id=$RID AND email='$M';")"
check "the item starts undecided" "PENDING" \
    "$(q "SELECT decision FROM access_review_items WHERE review_id=$RID AND email='$M';")"
check "only one review may be open" "ERROR|REVIEW_ALREADY_OPEN" \
    "$(run OPEN_ACCESS_REVIEW "$A2" 2026-11-01 2026-11-30 "")"
check "the opening is audited" "1" \
    "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='ACCESS_REVIEW_OPENED' AND entity_id='$RID';")"

# --- reading the review ----------------------------------------------------------
LISTED="$(run LIST_ACCESS_REVIEWS "$A1" OPEN 50 0)"
check_contains "the review is listed" "SUCCESS|REVIEWS|" "$LISTED"
check_contains "the list names the period" "2026-10-01" "$LISTED"
check "a non-admin cannot list reviews" "ERROR|FORBIDDEN" \
    "$(run LIST_ACCESS_REVIEWS "$M" OPEN 50 0)"
check "an unknown state filter is refused" "ERROR|INVALID_INPUT" \
    "$(run LIST_ACCESS_REVIEWS "$A1" MAYBE 50 0)"
check "an unknown review is not found" "ERROR|UNKNOWN_TRANSACTION" \
    "$(run GET_ACCESS_REVIEW "$A1" 999999 "")"
GET="$(run GET_ACCESS_REVIEW "$A1" "$RID" "")"
check_contains "the review is read back" "SUCCESS|REVIEW|$RID|2026-10-01|2026-10-31|OPEN|" "$GET"
check_contains "the items carry the decision" "PENDING" "$GET"

# --- deciding an item ------------------------------------------------------------
ITEM_M="$(q "SELECT item_id FROM access_review_items WHERE review_id=$RID AND email='$M';")"
ITEM_A1="$(q "SELECT item_id FROM access_review_items WHERE review_id=$RID AND email='$A1';")"
check "a non-admin cannot decide an item" "ERROR|FORBIDDEN" \
    "$(run DECIDE_ACCESS_ITEM "$M" "$ITEM_M" ATTESTED "")"
check "the reviewer may not attest its own access" "ERROR|FORBIDDEN" \
    "$(run DECIDE_ACCESS_ITEM "$A1" "$ITEM_A1" ATTESTED "")"
check "the refused self-attestation is audited" "1" \
    "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='AUTHZ_DENIED' AND entity_id='DECIDE_ACCESS_ITEM' AND detail='$A1';")"
check "an unknown decision is refused" "ERROR|INVALID_INPUT" \
    "$(run DECIDE_ACCESS_ITEM "$A1" "$ITEM_M" MAYBE "")"
check "an unknown item is not found" "ERROR|UNKNOWN_TRANSACTION" \
    "$(run DECIDE_ACCESS_ITEM "$A1" 999999 ATTESTED "")"
check "another admin may decide an item" "SUCCESS|ITEM_DECIDED|$ITEM_M|ATTESTED" \
    "$(run DECIDE_ACCESS_ITEM "$A2" "$ITEM_M" ATTESTED "still needed")"
check "the decision is recorded" "ATTESTED" \
    "$(q "SELECT decision FROM access_review_items WHERE item_id=$ITEM_M;")"
check "the reviewer is recorded" "$A2" \
    "$(q "SELECT reviewer_email FROM access_review_items WHERE item_id=$ITEM_M;")"
check "the note is recorded" "still needed" \
    "$(q "SELECT note FROM access_review_items WHERE item_id=$ITEM_M;")"
check "an item cannot be decided twice" "ERROR|INVALID_STATUS" \
    "$(run DECIDE_ACCESS_ITEM "$A1" "$ITEM_M" ATTESTED "")"
check "the decision is audited" "1" \
    "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='ACCESS_REVIEW_DECIDED' AND entity_id='$ITEM_M';")"

# --- closing the review ----------------------------------------------------------
check "the review cannot close while an item is undecided" "ERROR|REVIEW_INCOMPLETE" \
    "$(run CLOSE_ACCESS_REVIEW "$A1" "$RID")"

# The snapshot covers every privileged account in the database, so the
# reviewer decides the remaining items: A1 decides everyone else's, and A2
# decides A1's own (a reviewer is never the subject).
ITEM_A2="$(q "SELECT item_id FROM access_review_items WHERE review_id=$RID AND email='$A2';")"
run DECIDE_ACCESS_ITEM "$A1" "$ITEM_A2" REVOKED "left the team" >/dev/null
check "a revoked item is recorded" "REVOKED" \
    "$(q "SELECT decision FROM access_review_items WHERE item_id=$ITEM_A2;")"
for item in $(q "SELECT item_id FROM access_review_items WHERE review_id=$RID AND decision='PENDING' AND email<>'$A1';"); do
    run DECIDE_ACCESS_ITEM "$A1" "$item" ATTESTED "" >/dev/null
done
run DECIDE_ACCESS_ITEM "$A2" "$ITEM_A1" ATTESTED "" >/dev/null
check "every item is decided" "0" \
    "$(q "SELECT COUNT(*) FROM access_review_items WHERE review_id=$RID AND decision='PENDING';")"
check "the review cannot close while the revoked access is still live" "ERROR|REVOCATION_PENDING" \
    "$(run CLOSE_ACCESS_REVIEW "$A1" "$RID")"
run CHANGE_ROLE "$A2" USER "$A1" >/dev/null
check "the review closes once the revoked access is gone" "SUCCESS|REVIEW_CLOSED|$RID" \
    "$(run CLOSE_ACCESS_REVIEW "$A1" "$RID")"
check "the review is closed" "CLOSED" \
    "$(q "SELECT state FROM access_reviews WHERE review_id=$RID;")"
check "the closer is recorded" "$A1" \
    "$(q "SELECT closed_by FROM access_reviews WHERE review_id=$RID;")"
check "a closed review cannot be closed again" "ERROR|INVALID_STATUS" \
    "$(run CLOSE_ACCESS_REVIEW "$A1" "$RID")"
check "the close is audited" "1" \
    "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='ACCESS_REVIEW_CLOSED' AND entity_id='$RID';")"
check_contains "a new review may be opened after the close" "SUCCESS|REVIEW_OPENED|" \
    "$(run OPEN_ACCESS_REVIEW "$A1" 2026-11-01 2026-11-30 "")"
check "the closed review is listed under CLOSED" "1" \
    "$(run LIST_ACCESS_REVIEWS "$A1" CLOSED 50 0 | cut -d'|' -f4 | tr ';' '\n' | grep -c "^$RID:")"

# --- the sign-in time is recorded ------------------------------------------------
q "UPDATE users SET last_login_at = NULL WHERE email='$U';"
run AUTH_LOGIN "$U" secret "" >/dev/null
check "a successful login records the sign-in time" "1" \
    "$(q "SELECT COUNT(*) FROM users WHERE email='$U' AND last_login_at IS NOT NULL;")"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
