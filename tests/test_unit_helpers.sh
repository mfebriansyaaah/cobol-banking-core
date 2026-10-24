#!/bin/bash
# Unit suite for pure C helpers: hash_password_v2 + verify_password round-trip
# and wrong-password rejection. Compiles the real library sources with ASan.
# Usage: ./tests/test_unit_helpers.sh

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1));
    else echo -e "${RED}FAIL${NC} $name (expected [$expected] got [$actual])"; failed=$((failed+1)); fi
}

echo "======================================================================"
echo "  UNIT HELPERS SUITE"
echo "======================================================================"

cat > "$TMP/h.c" <<'C'
#include <stdio.h>
#include <string.h>
void hash_password_v2(char *password, char *output_hash);
void verify_password(char *password, char *stored_hash, char *result);
int main(void){
    char h[256]; memset(h,0,sizeof(h));
    hash_password_v2("secret123", h);
    char r1='X', r2='X';
    verify_password("secret123", h, &r1);
    verify_password("wrong", h, &r2);
    printf("HASH=%s\nVERIFY_OK=%c\nVERIFY_BAD=%c\n", h, r1, r2);
    return 0;
}
C
if gcc -fsanitize=address -fno-omit-frame-pointer -O1 -I cobol/c_lib \
     "$TMP/h.c" cobol/c_lib/hash_lib.c cobol/c_lib/random_lib.c cobol/c_lib/settings_lib.c \
     -o "$TMP/h" -lpthread 2>"$TMP/err"; then
    out=$("$TMP/h")
    hash=$(echo "$out" | sed -n 's/^HASH=//p')
    vok=$(echo "$out" | sed -n 's/^VERIFY_OK=//p')
    vbad=$(echo "$out" | sed -n 's/^VERIFY_BAD=//p')
    check "hash has PBKDF2 prefix" "PBKDF2" "$(echo "$hash" | cut -d'$' -f1)"
    check "correct password verifies" "1" "$vok"
    check "wrong password rejected" "0" "$vbad"
else
    echo "compile failed:"; cat "$TMP/err"; failed=3
fi

echo "----------------------------------------------------------------------"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]