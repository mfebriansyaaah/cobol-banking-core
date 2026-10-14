#!/bin/bash
# Password KDF suite: the PBKDF2 cost is configurable (default follows modern
# guidance), old hashes keep verifying, and a hash below the current target is
# transparently rehashed on login.
# Usage: ./tests/test_password_kdf.sh

BIN="./cobol/bin/main_logic"

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }

# Run an action with an explicit KDF cost.
run_it() {
    local it="$1"; shift
    printf "%s|%s|%s|%s|%s\n" "$1" "$2" "$3" "$4" "$5" > input.txt
    PBKDF2_ITERATIONS="$it" "$BIN" >/dev/null 2>&1
    cat output.txt
}

# Run an action with the compiled default cost (env removed).
run_def() {
    printf "%s|%s|%s|%s|%s\n" "$1" "$2" "$3" "$4" "$5" > input.txt
    env -u PBKDF2_ITERATIONS "$BIN" >/dev/null 2>&1
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

iter_of() { q "SELECT SUBSTRING_INDEX(password_hash,'\$',2) FROM users WHERE email='$1';"; }

echo "======================================================================"
echo "  PASSWORD KDF SUITE"
echo "======================================================================"

# --- cost is configurable ------------------------------------------------
A="kdf_a@test.com"
q "DELETE FROM verification_logs WHERE email='$A'; DELETE FROM users WHERE email='$A';"
run_it 20000 REQUEST_SIGNUP "$A" secret123 'Kdf A' '1990-01-01' >/dev/null
check "custom cost is honored" "PBKDF2\$20000" "$(iter_of "$A")"
q "DELETE FROM verification_logs WHERE email='$A'; DELETE FROM users WHERE email='$A';"

B="kdf_b@test.com"
q "DELETE FROM verification_logs WHERE email='$B'; DELETE FROM users WHERE email='$B';"
run_def REQUEST_SIGNUP "$B" secret123 'Kdf B' '1990-01-01' >/dev/null
check "default cost is modern" "PBKDF2\$600000" "$(iter_of "$B")"
q "DELETE FROM verification_logs WHERE email='$B'; DELETE FROM users WHERE email='$B';"

# --- legacy SHA256 is verified and upgraded ------------------------------
C="kdf_c@test.com"
q "DELETE FROM verification_logs WHERE email='$C'; DELETE FROM users WHERE email='$C';
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (970,'$C',CONCAT('SHA256_',SHA2('secret',256)),'Kdf C','1990-01-01','VERIFIED','USER');"
check "legacy SHA256 still verifies" "SUCCESS|LOGIN_OK" "$(run_it 40000 AUTH_LOGIN "$C" secret)"
check "legacy SHA256 is upgraded" "PBKDF2\$40000" "$(iter_of "$C")"
q "DELETE FROM verification_logs WHERE email='$C'; DELETE FROM users WHERE email='$C';"

# --- an old PBKDF2 hash is rehashed up on login --------------------------
D="kdf_d@test.com"
q "DELETE FROM verification_logs WHERE email='$D'; DELETE FROM users WHERE email='$D';"
dc=$(run_it 20000 REQUEST_SIGNUP "$D" secret123 'Kdf D' '1990-01-01' | cut -d'|' -f3)
run_it 20000 VERIFY_EMAIL "$D" "$dc" >/dev/null
check "old PBKDF2 verifies and rehashes" "SUCCESS|LOGIN_OK" "$(run_it 40000 AUTH_LOGIN "$D" secret123)"
check "hash moved to the new cost" "PBKDF2\$40000" "$(iter_of "$D")"

# A hash already at the target cost must not be rehashed.
h1=$(q "SELECT password_hash FROM users WHERE email='$D';")
run_it 40000 AUTH_LOGIN "$D" secret123 >/dev/null
h2=$(q "SELECT password_hash FROM users WHERE email='$D';")
[ "$h1" = "$h2" ] && check "no rehash when at target" "same" "same" || check "no rehash when at target" "same" "changed"
check "password still valid after rehash" "SUCCESS|LOGIN_OK" "$(run_it 40000 AUTH_LOGIN "$D" secret123)"
q "DELETE FROM verification_logs WHERE email='$D'; DELETE FROM users WHERE email='$D';"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
