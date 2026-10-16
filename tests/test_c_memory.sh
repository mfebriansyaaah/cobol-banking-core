#!/bin/bash
# C memory-boundary suite: the C/COBOL contract says single-char result fields
# hold one byte (no terminator is written) and code buffers hold their digits
# plus a terminator. This suite compiles a small AddressSanitizer harness
# against the real library sources, so any past-the-field write fails loudly
# instead of silently clobbering the neighbouring COBOL field. It also pins
# the PBKDF2 cost clamp (an absurd stored cost is refused fast, not burned).
# Usage: ./tests/test_c_memory.sh

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected [$expected] got [$actual])"; failed=$((failed+1))
    fi
}

echo "======================================================================"
echo "  C MEMORY-BOUNDARY SUITE"
echo "======================================================================"

cat > "$TMP/harness.c" <<'C'
#include <stdio.h>
#include <string.h>

void hash_password_v2(char *password, char *output_hash);
void verify_password(char *password, char *stored_hash, char *result);
void password_needs_rehash(char *stored_hash, char *result);
void totp_verify(char *secret_b32, char *code, char *result);
void generate_random_code(char *output_code);
void generate_mfa_secret(char *out);

static int all_digits(const char *s, size_t n) {
    for (size_t i = 0; i < n; i++) {
        if (s[i] < '0' || s[i] > '9') return 0;
    }
    return 1;
}

static int all_b32(const char *s, size_t n) {
    for (size_t i = 0; i < n; i++) {
        char c = s[i];
        if (!((c >= 'A' && c <= 'Z') || (c >= '2' && c <= '7'))) return 0;
    }
    return 1;
}

int main(int argc, char **argv) {
    /* 1-byte result fields, like the COBOL PIC X(1): any write past the
     * single byte aborts under AddressSanitizer. */
    char h[256];
    hash_password_v2("secret123", h);

    char r1;
    verify_password("secret123", h, &r1);
    printf("verify_match=%c\n", r1);
    verify_password("wrongpass", h, &r1);
    printf("verify_mismatch=%c\n", r1);

    char r2;
    password_needs_rehash(h, &r2);
    printf("rehash_current=%c\n", r2);
    password_needs_rehash("SHA256_9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08", &r2);
    printf("rehash_legacy=%c\n", r2);

    /* TOTP against a caller-supplied current code (argv[1]), plus a wrong one. */
    char r3;
    totp_verify("JBSWY3DPEHPK3PXP", argv[1], &r3);
    printf("totp_match=%c\n", r3);
    totp_verify("JBSWY3DPEHPK3PXP", "000000", &r3);
    printf("totp_mismatch=%c\n", r3);

    /* 7-byte code field (6 digits plus terminator, like the fixed WS-RAND). */
    char code[7];
    memset(code, 'X', sizeof(code));
    generate_random_code(code);
    printf("code6=%d\n", (int)strlen(code) == 6 && all_digits(code, 6));

    char secret[64];
    generate_mfa_secret(secret);
    printf("secret32=%d\n", (int)strlen(secret) == 32 && all_b32(secret, 32));

    /* An absurd stored cost must be refused without burning CPU. */
    char evil[256];
    snprintf(evil, sizeof(evil), "PBKDF2$2000000000$%32s$%64s",
             "0123456789abcdef0123456789abcdef",
             "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef");
    (void)argc;
    char r4;
    verify_password("secret123", evil, &r4);
    printf("absurd_cost=%c\n", r4);
    return 0;
}
C

build_rc=0
gcc -std=c11 -Wall -Wextra -g -fsanitize=address,undefined \
    -I cobol/c_lib -o "$TMP/harness" "$TMP/harness.c" \
    cobol/c_lib/hash_lib.c cobol/c_lib/totp_lib.c cobol/c_lib/random_lib.c \
    2>"$TMP/cc.err" || build_rc=1
check "boundary harness builds clean under ASan+UBSan" "0" "$build_rc"
[ "$build_rc" -eq 0 ] || { sed -n '1,10p' "$TMP/cc.err"; echo "cannot run the harness"; exit 1; }

CODE=$(python3 - <<'PY'
import base64, hmac, hashlib, struct, time
t = time.time()
c = int(t) // 30
if t % 30 > 25:
    c += 1
key = base64.b32decode('JBSWY3DPEHPK3PXP')
h = hmac.new(key, struct.pack('>Q', c), hashlib.sha1).digest()
o = h[-1] & 0xf
print(f"{struct.unpack('>I', h[o:o+4])[0] & 0x7fffffff:06d}"[-6:])
PY
)

START=$SECONDS
OUT=$(PBKDF2_ITERATIONS=1000 "$TMP/harness" "$CODE" 2>"$TMP/asan.err")
run_rc=$?
ELAPSED=$((SECONDS - START))
check "harness exits clean (no sanitizer abort)" "0" "$run_rc"
[ "$run_rc" -eq 0 ] || tail -5 "$TMP/asan.err"

val() { echo "$OUT" | grep -E "^$1=" | cut -d'=' -f2; }
check "password verifies" "1" "$(val verify_match)"
check "wrong password rejected" "0" "$(val verify_mismatch)"
check "current cost needs no rehash" "0" "$(val rehash_current)"
check "legacy hash needs rehash" "1" "$(val rehash_legacy)"
check "TOTP verifies" "1" "$(val totp_match)"
check "wrong TOTP rejected" "0" "$(val totp_mismatch)"
check "random code is 6 digits" "1" "$(val code6)"
check "MFA secret is 32 base32 chars" "1" "$(val secret32)"
check "absurd KDF cost refused" "0" "$(val absurd_cost)"
[ "$ELAPSED" -lt 20 ] && check "absurd cost refused fast" "fast" "fast" \
    || check "absurd cost refused fast" "fast" "${ELAPSED}s"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
