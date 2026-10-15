#!/bin/bash
# Step-up (re-authentication) suite: VERIFY_REAUTH re-checks the caller's own
# password (and TOTP when MFA is on) without issuing tokens or touching lockout.
# Usage: ./tests/test_stepup.sh

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

# Current TOTP for a base32 secret (RFC 6238 / SHA-1 / 30s).
totp() {
    python3 - "$1" <<'PY'
import base64,hmac,hashlib,struct,sys,time
s=base64.b32decode(sys.argv[1].upper()+'='*((8-len(sys.argv[1])%8)%8))
c=int(time.time())//30
h=hmac.new(s,struct.pack('>Q',c),hashlib.sha1).digest()
o=h[-1]&0xf
print(str((struct.unpack('>I',h[o:o+4])[0]&0x7fffffff)%1000000).zfill(6))
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

echo "======================================================================"
echo "  STEP-UP (RE-AUTHENTICATION) SUITE"
echo "======================================================================"

P="su_pw@test.com"; M="su_mfa@test.com"; S="su_susp@test.com"
q "DELETE FROM users WHERE email IN ('$P','$M','$S');
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role,mfa_enabled,mfa_secret) VALUES
   (870,'$P',CONCAT('SHA256_',SHA2('secret123',256)),'P','1990-01-01','VERIFIED','SUPER_ADMIN',FALSE,NULL),
   (871,'$M',CONCAT('SHA256_',SHA2('secret123',256)),'M','1990-01-01','VERIFIED','SUPER_ADMIN',TRUE,'JBSWY3DPEHPK3PXP'),
   (872,'$S',CONCAT('SHA256_',SHA2('secret123',256)),'S','1990-01-01','SUSPENDED','USER',FALSE,NULL);"

check "correct password re-authenticates" "SUCCESS|REAUTH_OK" "$(run VERIFY_REAUTH "$P" secret123)"
check "wrong password rejected" "ERROR|INVALID_CREDENTIALS" "$(run VERIFY_REAUTH "$P" nope)"
check "unknown account rejected" "ERROR|INVALID_CREDENTIALS" "$(run VERIFY_REAUTH ghost_su@test.com secret123)"
check "suspended account rejected" "ERROR|INVALID_CREDENTIALS" "$(run VERIFY_REAUTH "$S" secret123)"
check "MFA on: code required" "ERROR|MFA_REQUIRED" "$(run VERIFY_REAUTH "$M" secret123)"
check "MFA on: bad code rejected" "ERROR|INVALID_MFA" "$(run VERIFY_REAUTH "$M" secret123 000000)"
check "MFA on: good code re-authenticates" "SUCCESS|REAUTH_OK" "$(run VERIFY_REAUTH "$M" secret123 "$(totp JBSWY3DPEHPK3PXP)")"
check "MFA on: wrong password still rejected" "ERROR|INVALID_CREDENTIALS" "$(run VERIFY_REAUTH "$M" nope "$(totp JBSWY3DPEHPK3PXP)")"

q "DELETE FROM users WHERE email IN ('$P','$M','$S');"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
