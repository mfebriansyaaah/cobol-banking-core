#!/bin/bash
# Verification attempt cap: a code can be guessed only a few times. After the
# cap (5) the code is burned, so even the correct code fails and a fresh one
# must be requested. Covers SIGNUP, PASSWORD_RESET and EMAIL_CHANGE.
# Usage: ./tests/test_verify_cap.sh

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

echo "======================================================================"
echo "  VERIFICATION ATTEMPT CAP SUITE"
echo "======================================================================"

# --- SIGNUP: a few guesses are tolerated, the cap burns the code ---------
A="cap_a@test.com"
q "DELETE FROM verification_logs WHERE email='$A'; DELETE FROM users WHERE email='$A';"
acs=$(run REQUEST_SIGNUP "$A" secret123 'Cap A' '1990-01-01'); ac=$(echo "$acs" | cut -d'|' -f3)
for i in 1 2 3; do run VERIFY_EMAIL "$A" 000000 >/dev/null; done
check "below cap: correct code still works" "SUCCESS|EMAIL_VERIFIED" "$(run VERIFY_EMAIL "$A" "$ac")"

B="cap_b@test.com"
q "DELETE FROM verification_logs WHERE email='$B'; DELETE FROM users WHERE email='$B';"
bcs=$(run REQUEST_SIGNUP "$B" secret123 'Cap B' '1990-01-01'); bc=$(echo "$bcs" | cut -d'|' -f3)
for i in 1 2 3 4 5; do run VERIFY_EMAIL "$B" 000000 >/dev/null; done
check "cap reached: attempts recorded" "5" "$(q "SELECT attempts FROM verification_logs WHERE email='$B' AND purpose='SIGNUP' ORDER BY id DESC LIMIT 1;")"
check "at cap: code burned" "ERROR|INVALID_CODE" "$(run VERIFY_EMAIL "$B" "$bc")"
run RESEND_VERIFICATION "$B" '' '' '' >/dev/null
bc2=$(q "SELECT code FROM verification_logs WHERE email='$B' AND purpose='SIGNUP' AND is_used=0 ORDER BY id DESC LIMIT 1;")
check "fresh code after cap verifies" "SUCCESS|EMAIL_VERIFIED" "$(run VERIFY_EMAIL "$B" "$bc2")"
q "DELETE FROM verification_logs WHERE email='$B'; DELETE FROM users WHERE email='$B';"

# --- PASSWORD_RESET ------------------------------------------------------
C="cap_c@test.com"
q "DELETE FROM verification_logs WHERE email='$C'; DELETE FROM users WHERE email='$C';"
ccs=$(run REQUEST_SIGNUP "$C" secret123 'Cap C' '1990-01-01'); cc=$(echo "$ccs" | cut -d'|' -f3)
run VERIFY_EMAIL "$C" "$cc" >/dev/null
sf=$(run FORGOT_PASSWORD "$C" '' '' ''); sc=$(echo "$sf" | cut -d'|' -f3)
for i in 1 2 3 4 5; do run RESET_PASSWORD "$C" 000000 trypass123 >/dev/null; done
check "reset: cap reached" "5" "$(q "SELECT attempts FROM verification_logs WHERE email='$C' AND purpose='PASSWORD_RESET' ORDER BY id DESC LIMIT 1;")"
check "reset: code burned at cap" "ERROR|INVALID_CODE" "$(run RESET_PASSWORD "$C" "$sc" trypass123)"
run FORGOT_PASSWORD "$C" '' '' '' >/dev/null
sc2=$(q "SELECT code FROM verification_logs WHERE email='$C' AND purpose='PASSWORD_RESET' AND is_used=0 ORDER BY id DESC LIMIT 1;")
check "reset: fresh code works" "SUCCESS|PASSWORD_RESET" "$(run RESET_PASSWORD "$C" "$sc2" trypass123)"
q "DELETE FROM verification_logs WHERE email='$C'; DELETE FROM users WHERE email='$C';"

# --- EMAIL_CHANGE --------------------------------------------------------
D="cap_d@test.com"; DN="cap_d_new@test.com"
q "DELETE FROM verification_logs WHERE email IN ('$D','$DN'); DELETE FROM users WHERE email IN ('$D','$DN');"
dcs=$(run REQUEST_SIGNUP "$D" secret123 'Cap D' '1990-01-01'); dc=$(echo "$dcs" | cut -d'|' -f3)
run VERIFY_EMAIL "$D" "$dc" >/dev/null
ef=$(run REQ_EMAIL_CHANGE "$D" "$DN" "$D"); ec=$(echo "$ef" | cut -d'|' -f3)
# A second request must invalidate the first code (single active code).
run REQ_EMAIL_CHANGE "$D" "$DN" "$D" >/dev/null
check "email change: previous code invalidated" "ERROR|INVALID_CODE" "$(run CONFIRM_EMAIL_CHANGE "$D" "$DN" "$ec" "$D")"
ec2=$(q "SELECT code FROM verification_logs WHERE email='$DN' AND purpose='EMAIL_CHANGE' AND is_used=0 ORDER BY id DESC LIMIT 1;")
for i in 1 2 3 4 5; do run CONFIRM_EMAIL_CHANGE "$D" "$DN" 000000 "$D" >/dev/null; done
check "email change: cap reached" "5" "$(q "SELECT attempts FROM verification_logs WHERE email='$DN' AND purpose='EMAIL_CHANGE' ORDER BY id DESC LIMIT 1;")"
check "email change: code burned at cap" "ERROR|INVALID_CODE" "$(run CONFIRM_EMAIL_CHANGE "$D" "$DN" "$ec2" "$D")"
q "DELETE FROM verification_logs WHERE email IN ('$D','$DN'); DELETE FROM users WHERE email IN ('$D','$DN');"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
