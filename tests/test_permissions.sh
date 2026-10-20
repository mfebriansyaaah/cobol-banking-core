#!/bin/bash
# Scoped-permission suite (ADR 0074): CHECK_PERMISSION answers whether an
# account holds a permission, LIST_PERMISSIONS lists what an account holds,
# and the read-mostly gates (LIST_AUDIT, ARCHIVE_AUDIT, RECONCILE,
# LIST_RECONCILIATIONS, LIST_EXCEPTIONS) enforce the permission instead of
# the rank. Phase 1 reproduces the current behavior exactly: SUPER_ADMIN
# holds every catalogued permission, other roles hold none. A grant inserted
# as data (then removed) proves the mechanism is data-driven.
# Usage: ./tests/test_permissions.sh

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

check_not_contains() {
    local name="$1" expected="$2" actual="$3"
    if [[ "$actual" != *"$expected"* ]]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected not to contain [$expected] got [$actual])"; failed=$((failed+1))
    fi
}

A="pm_sa@test.com"; M="pm_sm@test.com"; U="pm_su@test.com"

setup() {
    q "DELETE FROM users WHERE email IN ('$A','$M','$U');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1971,'$A',CONCAT('SHA256_',SHA2('secret',256)),'PM Super','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1972,'$M',CONCAT('SHA256_',SHA2('secret',256)),'PM Manager','1990-01-01','VERIFIED','MANAGER'),
       (1973,'$U',CONCAT('SHA256_',SHA2('secret',256)),'PM User','1990-01-01','VERIFIED','USER');"
}

teardown() {
    q "DELETE FROM role_permissions WHERE role='MANAGER' AND permission='AUDIT_READ';
       DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND detail IN ('$A','$M','$U');
       DELETE FROM users WHERE email IN ('$A','$M','$U');"
}
trap teardown EXIT

echo "======================================================================"
echo "  SCOPED PERMISSION SUITE"
echo "======================================================================"

setup

# --- CHECK_PERMISSION answers ----------------------------------------------------
check "a SUPER_ADMIN holds AUDIT_READ" "SUCCESS|PERMISSION_OK" \
    "$(run CHECK_PERMISSION "$A" AUDIT_READ "")"
check "a SUPER_ADMIN holds AUDIT_ARCHIVE" "SUCCESS|PERMISSION_OK" \
    "$(run CHECK_PERMISSION "$A" AUDIT_ARCHIVE "")"
check "a SUPER_ADMIN holds RECONCILE_READ" "SUCCESS|PERMISSION_OK" \
    "$(run CHECK_PERMISSION "$A" RECONCILE_READ "")"
check "a SUPER_ADMIN holds RECONCILE_RUN" "SUCCESS|PERMISSION_OK" \
    "$(run CHECK_PERMISSION "$A" RECONCILE_RUN "")"
check "a MANAGER is denied AUDIT_READ" "ERROR|PERMISSION_DENIED" \
    "$(run CHECK_PERMISSION "$M" AUDIT_READ "")"
check "a USER is denied RECONCILE_RUN" "ERROR|PERMISSION_DENIED" \
    "$(run CHECK_PERMISSION "$U" RECONCILE_RUN "")"
check "an unknown permission is refused" "ERROR|INVALID_INPUT" \
    "$(run CHECK_PERMISSION "$A" NO_SUCH_PERM "")"
check "a lowercase permission is refused" "ERROR|INVALID_INPUT" \
    "$(run CHECK_PERMISSION "$A" audit_read "")"
check "an unknown account is not found" "ERROR|ACCOUNT_NOT_FOUND" \
    "$(run CHECK_PERMISSION ghost@test.com AUDIT_READ "")"

# --- LIST_PERMISSIONS projects ---------------------------------------------------
check "a SUPER_ADMIN lists the whole catalog" "AUDIT_ARCHIVE;AUDIT_READ;RECONCILE_READ;RECONCILE_RUN" \
    "$(run LIST_PERMISSIONS "$A" "" "" | cut -d'|' -f3)"
check "a plain user lists nothing" "SUCCESS|PERMISSIONS" \
    "$(run LIST_PERMISSIONS "$U" "" "")"
check "an unknown account is not found" "ERROR|ACCOUNT_NOT_FOUND" \
    "$(run LIST_PERMISSIONS ghost@test.com "" "")"

# --- the migrated gates enforce the permission -----------------------------------
check "a MANAGER cannot read the audit trail" "ERROR|FORBIDDEN" \
    "$(run LIST_AUDIT "$M" "" "" "")"
check "a USER cannot reconcile" "ERROR|FORBIDDEN" \
    "$(run RECONCILE "$U" "" "")"
check "a MANAGER cannot list reconciliation runs" "ERROR|FORBIDDEN" \
    "$(run LIST_RECONCILIATIONS "$M" "" "")"
check "a USER cannot list exceptions" "ERROR|FORBIDDEN" \
    "$(run LIST_EXCEPTIONS "$U" "" "")"
check "a MANAGER cannot archive the audit trail" "ERROR|FORBIDDEN" \
    "$(run ARCHIVE_AUDIT 30 "$M" "")"
check "a MANAGER cannot record a reconciliation" "ERROR|FORBIDDEN" \
    "$(run RUN_RECONCILIATION "$M" MANUAL "")"
check "a refused gated read is audited" "1" \
    "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='AUTHZ_DENIED' AND entity_id='LIST_AUDIT' AND detail='$M';")"

# --- the privileged paths still work ----------------------------------------------
check_contains "a SUPER_ADMIN reads the audit trail" "SUCCESS|AUDIT|" \
    "$(run LIST_AUDIT "$A" "" "" "")"
check_not_contains "a SUPER_ADMIN reconciles" "FORBIDDEN" \
    "$(run RECONCILE "$A" "" "")"

# --- permissions are data: a grant takes effect, its removal revokes it -----------
q "INSERT INTO role_permissions (role, permission) VALUES ('MANAGER','AUDIT_READ');"
check_contains "a granted MANAGER reads the audit trail" "SUCCESS|AUDIT|" \
    "$(run LIST_AUDIT "$M" "" "" "")"
q "DELETE FROM role_permissions WHERE role='MANAGER' AND permission='AUDIT_READ';"
check "removing the grant restores the refusal" "ERROR|FORBIDDEN" \
    "$(run LIST_AUDIT "$M" "" "" "")"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
