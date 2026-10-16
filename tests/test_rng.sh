#!/bin/bash
# RNG suite: every security-sensitive random value (password salt, MFA/TOTP
# secret) comes from the fail-closed OS CSPRNG helper and is fresh per call.
# Usage: ./tests/test_rng.sh

BIN="./cobol/bin/main_logic"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

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
echo "  RNG (CSPRNG) SUITE"
echo "======================================================================"

# --- fail-closed OS helper -------------------------------------------------
cat > "$TMP/probe.c" <<'C'
#include <stdio.h>
#include <string.h>
#include "random_lib.h"
int main(void) {
    unsigned char a[16], b[16];
    int zero = 1;
    secure_random_bytes(a, sizeof a);
    secure_random_bytes(b, sizeof b);
    for (size_t i = 0; i < sizeof a; i++) if (a[i]) zero = 0;
    printf("%s %s\n", memcmp(a, b, sizeof a) != 0 ? "DIFFER" : "SAME",
                        zero ? "ZERO" : "NONZERO");
    return 0;
}
C

build_rc=0
gcc -Wall -Wextra -I cobol/c_lib -o "$TMP/probe" "$TMP/probe.c" \
    cobol/c_lib/random_lib.c 2>"$TMP/cc.err" || build_rc=1
check "OS RNG helper builds cleanly" "0" "$build_rc"
[ "$build_rc" -eq 0 ] || sed -n '1,5p' "$TMP/cc.err"
check "two RNG draws differ" "DIFFER" "$("$TMP/probe" 2>/dev/null | cut -d' ' -f1)"
check "RNG output is non-zero" "NONZERO" "$("$TMP/probe" 2>/dev/null | cut -d' ' -f2)"

# --- fresh MFA secrets (two pending enrolments) ----------------------------
U="rng_mfa@test.com"
q "DELETE FROM users WHERE email='$U'; DELETE FROM verification_logs WHERE email='$U';"
c=$(run REQUEST_SIGNUP "$U" secret123 'Rng Mfa' '1990-01-01' | cut -d'|' -f3)
run VERIFY_EMAIL "$U" "$c" >/dev/null
run MFA_ENROLL_BEGIN "$U" "$U" >/dev/null
S1=$(q "SELECT mfa_secret FROM users WHERE email='$U';")
run MFA_ENROLL_BEGIN "$U" "$U" >/dev/null
S2=$(q "SELECT mfa_secret FROM users WHERE email='$U';")
[ -n "$S1" ] && [ "$S1" != "$S2" ] && check "MFA secrets are fresh" "fresh" "fresh" \
    || check "MFA secrets are fresh" "fresh" "reused"

# --- fresh password salts --------------------------------------------------
A="rng_a@test.com"; B="rng_b@test.com"
q "DELETE FROM users WHERE email IN ('$A','$B'); DELETE FROM verification_logs WHERE email IN ('$A','$B');"
run REQUEST_SIGNUP "$A" samepass123 'Rng A' '1990-01-01' >/dev/null
run REQUEST_SIGNUP "$B" samepass123 'Rng B' '1990-01-01' >/dev/null
HA=$(q "SELECT password_hash FROM users WHERE email='$A';")
HB=$(q "SELECT password_hash FROM users WHERE email='$B';")
[ -n "$HA" ] && [ "$HA" != "$HB" ] && check "same password gets a fresh salt" "fresh" "fresh" \
    || check "same password gets a fresh salt" "fresh" "reused"

q "DELETE FROM users WHERE email IN ('$U','$A','$B'); DELETE FROM verification_logs WHERE email IN ('$U','$A','$B');"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
