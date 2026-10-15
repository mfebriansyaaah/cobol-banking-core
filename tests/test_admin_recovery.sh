#!/bin/bash
# Admin recovery suite: a SUPER_ADMIN/MANAGER (not lower-ranked) can clear a
# user's lockout (UNLOCK_USER) and reset a user's MFA (ADMIN_RESET_MFA); a plain
# user cannot, and the actor may not target a higher-ranked account. Both are
# audited with subject + actor.
# Usage: ./tests/test_admin_recovery.sh

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
echo "  ADMIN RECOVERY SUITE"
echo "======================================================================"

SA="ar2_super@test.com"; MG="ar2_mgr@test.com"; U="ar2_user@test.com"
q "DELETE FROM users WHERE email IN ('$SA','$MG','$U');
   DELETE FROM audit_trail WHERE action IN ('UNLOCK_USER','ADMIN_RESET_MFA');
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role,failed_logins,locked_until,mfa_enabled,mfa_secret) VALUES
   (850,'$SA','x','S','1990-01-01','VERIFIED','SUPER_ADMIN',0,NULL,FALSE,NULL),
   (851,'$MG','x','M','1990-01-01','VERIFIED','MANAGER',0,NULL,FALSE,NULL),
   (852,'$U','x','U','1990-01-01','VERIFIED','USER',3, DATE_ADD(NOW(), INTERVAL 10 MINUTE), TRUE, 'SECRETX');"

# --- UNLOCK_USER ---------------------------------------------------------
check "plain user cannot unlock" "ERROR|FORBIDDEN" "$(run UNLOCK_USER "$U" "$U")"
check "MANAGER cannot unlock a SUPER_ADMIN" "ERROR|FORBIDDEN" "$(run UNLOCK_USER "$SA" "$MG")"
check "unknown target" "ERROR|ACCOUNT_NOT_FOUND" "$(run UNLOCK_USER nost_ar2@test.com "$SA")"
check "admin unlocks a locked user" "SUCCESS|ACCOUNT_UNLOCKED" "$(run UNLOCK_USER "$U" "$SA")"
check "lockout cleared" "1" "$(q "SELECT COUNT(*) FROM users WHERE email='$U' AND locked_until IS NULL AND failed_logins=0")"
check "unlock is audited (subject + actor)" "852/850" "$(q "SELECT CONCAT(user_id,'/',actor_id) FROM audit_trail WHERE action='UNLOCK_USER' ORDER BY audit_id DESC LIMIT 1")"

# --- ADMIN_RESET_MFA -----------------------------------------------------
check "plain user cannot reset MFA" "ERROR|FORBIDDEN" "$(run ADMIN_RESET_MFA "$U" "$U")"
check "MANAGER cannot reset a SUPER_ADMIN's MFA" "ERROR|FORBIDDEN" "$(run ADMIN_RESET_MFA "$SA" "$MG")"
check "admin resets a user's MFA" "SUCCESS|MFA_RESET" "$(run ADMIN_RESET_MFA "$U" "$SA")"
check "MFA cleared" "1" "$(q "SELECT COUNT(*) FROM users WHERE email='$U' AND mfa_enabled=0 AND mfa_secret IS NULL")"
check "MFA reset is audited (subject + actor)" "852/850" "$(q "SELECT CONCAT(user_id,'/',actor_id) FROM audit_trail WHERE action='ADMIN_RESET_MFA' ORDER BY audit_id DESC LIMIT 1")"

q "DELETE FROM users WHERE email IN ('$SA','$MG','$U'); DELETE FROM audit_trail WHERE action IN ('UNLOCK_USER','ADMIN_RESET_MFA');"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
