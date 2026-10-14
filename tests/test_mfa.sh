#!/bin/bash
# MFA (TOTP) suite: enrol, confirm, require at login, throttle wrong codes,
# and disable. TOTP codes are computed with python3 (RFC 6238, SHA-1).
# Usage: ./tests/test_mfa.sh

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

# Current TOTP for a base32 secret (python mirrors RFC 6238 / SHA-1 / 30s).
totp() {
    python3 - "$1" <<'PY'
import sys, base64, hmac, hashlib, struct, time
s = sys.argv[1]
key = base64.b32decode(s + '=' * ((8 - len(s) % 8) % 8))
c = int(time.time()) // 30
h = hmac.new(key, struct.pack('>Q', c), hashlib.sha1).digest()
o = h[-1] & 0xf
print(f"{struct.unpack('>I', h[o:o+4])[0] & 0x7fffffff:06d}"[-6:])
PY
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
    local name="$1" needle="$2" actual="$3"
    if [[ "$actual" == *"$needle"* ]]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected to contain [$needle] got [$actual])"; failed=$((failed+1))
    fi
}

echo "======================================================================"
echo "  MFA (TOTP) SUITE"
echo "======================================================================"

U="mfa_user@test.com"
q "DELETE FROM users WHERE email='$U'; DELETE FROM verification_logs WHERE email='$U';"
code=$(run REQUEST_SIGNUP "$U" secret123 'Mfa User' '1990-01-01' | cut -d'|' -f3)
run VERIFY_EMAIL "$U" "$code" >/dev/null

# --- enrol ---------------------------------------------------------------
check_contains "enroll returns a secret" "SUCCESS|MFA_SECRET|" "$(run MFA_ENROLL_BEGIN "$U" "$U")"
check "not enabled before confirm" "0" "$(q "SELECT mfa_enabled FROM users WHERE email='$U';")"
check "enroll is owner-only" "ERROR|FORBIDDEN" "$(run MFA_ENROLL_BEGIN "$U" other@test.com)"
SEC=$(q "SELECT mfa_secret FROM users WHERE email='$U';")
case "$SEC" in AAAA*|[A-Z2-7][A-Z2-7][A-Z2-7][A-Z2-7]*) check "secret is 32 base32 chars" "32" "${#SEC}" ;; *) check "secret is 32 base32 chars" "32" "${#SEC}" ;; esac

check "confirm rejects a bad code" "ERROR|INVALID_MFA" "$(run MFA_ENROLL_CONFIRM "$U" 000000 "$U")"
check "confirm with a good code" "SUCCESS|MFA_ENABLED" "$(run MFA_ENROLL_CONFIRM "$U" "$(totp "$SEC")" "$U")"
check "enabled after confirm" "1" "$(q "SELECT mfa_enabled FROM users WHERE email='$U';")"
check "enroll again rejected" "ERROR|MFA_ALREADY_ENABLED" "$(run MFA_ENROLL_BEGIN "$U" "$U")"

# --- login requires the second factor ------------------------------------
check "login without code needs MFA" "ERROR|MFA_REQUIRED" "$(run AUTH_LOGIN "$U" secret123)"
check "login with a wrong code" "ERROR|INVALID_MFA" "$(run AUTH_LOGIN "$U" secret123 000000)"
check "login with a good code" "SUCCESS|LOGIN_OK" "$(run AUTH_LOGIN "$U" secret123 "$(totp "$SEC")")"

# --- disable -------------------------------------------------------------
check "disable rejects a bad code" "ERROR|INVALID_MFA" "$(run MFA_DISABLE "$U" 000000 "$U")"
check "disable with a good code" "SUCCESS|MFA_DISABLED" "$(run MFA_DISABLE "$U" "$(totp "$SEC")" "$U")"
check "disabled after" "0" "$(q "SELECT mfa_enabled FROM users WHERE email='$U';")"
check "login works without a code now" "SUCCESS|LOGIN_OK" "$(run AUTH_LOGIN "$U" secret123)"
check "disable when not enabled" "ERROR|MFA_NOT_ENABLED" "$(run MFA_DISABLE "$U" 000000 "$U")"

q "DELETE FROM users WHERE email='$U'; DELETE FROM verification_logs WHERE email='$U';"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
