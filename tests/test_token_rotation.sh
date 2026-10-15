#!/bin/bash
# Token rotation suite: refresh sessions are consumed atomically; a replay of a
# consumed token is detected as reuse, which kills the whole family AND every
# access token (bumps the user's token_version), and is audited.
# Usage: ./tests/test_token_rotation.sh

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
echo "  TOKEN ROTATION SUITE"
echo "======================================================================"

U="rot_me@test.com"
q "DELETE FROM refresh_sessions WHERE email='$U'; DELETE FROM refresh_families WHERE email='$U'; DELETE FROM revoked_access_tokens WHERE email='$U'; DELETE FROM audit_trail WHERE user_id=983; DELETE FROM users WHERE email='$U';
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (983,'$U','x','Rot','1990-01-01','VERIFIED','USER');"

run STORE_SESSION jr1 "$U" 7 famR >/dev/null
V0=$(q "SELECT token_version FROM users WHERE email='$U';")

check "first consume wins" "SUCCESS|SESSION_CONSUMED" "$(run CONSUME_SESSION jr1)"
check "consumed token is revoked" "1" "$(q "SELECT revoked FROM refresh_sessions WHERE jti='jr1';")"
check "replay is reuse" "ERROR|SESSION_REUSED" "$(run CONSUME_SESSION jr1)"
check "reuse killed the family" "0" "$(q "SELECT COUNT(*) FROM refresh_sessions WHERE family='famR' AND revoked=0;")"
check "reuse bumped the token version" "1" "$(q "SELECT 1 WHERE (SELECT token_version FROM users WHERE email='$U') > $V0;")"
check "reuse is audited" "1" "$(q "SELECT COUNT(*) FROM audit_trail WHERE user_id=983 AND action='SESSION_REUSED' AND status='FAILED';")"

check "unknown token" "ERROR|SESSION_NOT_FOUND" "$(run CONSUME_SESSION no_such_jti)"

# An unrevoked but expired session is reported as expired, not consumed.
q "INSERT INTO refresh_sessions (jti,family,email,revoked,expires_at) VALUES ('jr2','famR2','$U',0, DATE_SUB(NOW(), INTERVAL 1 DAY));"
check "expired token" "ERROR|SESSION_EXPIRED" "$(run CONSUME_SESSION jr2)"
check "expired token not consumed" "0" "$(q "SELECT revoked FROM refresh_sessions WHERE jti='jr2';")"

# Family limits: absolute lifetime and rotation cap.
run STORE_SESSION jr3 "$U" 7 famR3 >/dev/null
check "family is tracked" "0" "$(q "SELECT rotations FROM refresh_families WHERE family='famR3';")"
check "first rotation counted" "SUCCESS|SESSION_CONSUMED" "$(run CONSUME_SESSION jr3)"
check "rotation count incremented" "1" "$(q "SELECT rotations FROM refresh_families WHERE family='famR3';")"

# Older than the absolute lifetime is refused and the family is revoked.
run STORE_SESSION jr4 "$U" 7 famR4 >/dev/null
q "UPDATE refresh_families SET created_at = DATE_SUB(NOW(), INTERVAL 40 DAY) WHERE family='famR4';"
check "absolute lifetime exceeded" "ERROR|SESSION_FAMILY_EXPIRED" "$(export REFRESH_ABSOLUTE_TTL_DAYS=30; run CONSUME_SESSION jr4)"
check "over-age family revoked" "1" "$(q "SELECT COUNT(*) FROM refresh_sessions WHERE family='famR4' AND revoked=1;")"
check "family expiry is a security event" "1" "$(q "SELECT COUNT(*) FROM audit_trail WHERE user_id=983 AND action='SESSION_FAMILY_EXPIRED' AND status='FAILED';")"

# Reaching the rotation cap refuses the next rotation.
run STORE_SESSION jr5 "$U" 7 famR5 >/dev/null
check "rotation within the cap" "SUCCESS|SESSION_CONSUMED" "$(export REFRESH_MAX_ROTATIONS=1; run CONSUME_SESSION jr5)"
run STORE_SESSION jr6 "$U" 7 famR5 >/dev/null
check "rotation cap reached" "ERROR|SESSION_FAMILY_EXPIRED" "$(export REFRESH_MAX_ROTATIONS=1; run CONSUME_SESSION jr6)"
check "cap expiry also audited" "2" "$(q "SELECT COUNT(*) FROM audit_trail WHERE user_id=983 AND action='SESSION_FAMILY_EXPIRED';")"

# Housekeeping: storing a session prunes expired denylist rows, keeps live ones.
q "INSERT INTO revoked_access_tokens (jti,email,expires_at) VALUES ('jr-old','$U', DATE_SUB(NOW(), INTERVAL 1 HOUR));"
q "INSERT INTO revoked_access_tokens (jti,email,expires_at) VALUES ('jr-live','$U', DATE_ADD(NOW(), INTERVAL 1 HOUR));"
run STORE_SESSION jr7 "$U" 7 famR7 >/dev/null
check "expired denylist row pruned" "0" "$(q "SELECT COUNT(*) FROM revoked_access_tokens WHERE jti='jr-old';")"
check "live denylist row kept" "1" "$(q "SELECT COUNT(*) FROM revoked_access_tokens WHERE jti='jr-live';")"

q "DELETE FROM refresh_sessions WHERE email='$U'; DELETE FROM refresh_families WHERE email='$U'; DELETE FROM revoked_access_tokens WHERE email='$U'; DELETE FROM audit_trail WHERE user_id=983; DELETE FROM users WHERE email='$U';"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
