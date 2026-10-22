#!/bin/bash
# Compliance export packages (Phase 1, Sprint 1 slice 17).
BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'; passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }
ADM="cex_admin@test.com"; USR="cex_user@test.com"; PKG="CEX_TEST"
cleanup() {
    q "DELETE FROM compliance_export_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM compliance_export_item WHERE package_code='$PKG';
       DELETE FROM compliance_export_package WHERE package_code='$PKG';
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1210,'$ADM','x','CEX Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1211,'$USR','x','CEX User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  COMPLIANCE EXPORT SUITE (PHASE 1)"
echo "======================================================================"
setup
check "create compliance package" "SUCCESS|CEX_PACKAGE_SAVED" \
    "$(run CEX_PACKAGE_SAVE "$PKG" SOX 'SOX audit package' 2026-01-01 2026-03-31 "$ADM")"
check_contains "get compliance package" "CEX_PACKAGE|$PKG|SOX" \
    "$(run CEX_PACKAGE_GET "$PKG" '' '' '' '' "$ADM")"
check "add package item" "SUCCESS|CEX_ITEM_ADDED" \
    "$(run CEX_ITEM_ADD "$PKG" AUDIT_QUERY Q1 'audit drill' '' "$ADM")"
check_contains "list package items" "AUDIT_QUERY:Q1:1:audit drill" \
    "$(run CEX_ITEM_LIST "$PKG" '' '' '' '' "$ADM")"
check "cannot attest before seal" "ERROR|INVALID_STATUS" \
    "$(run CEX_ATTEST "$PKG" 'premature' '' '' '' "$ADM")"
check_contains "seal package" "SUCCESS|CEX_SEALED|" \
    "$(run CEX_SEAL "$PKG" '' '' '' '' "$ADM")"
check "sealed package verifies" "SUCCESS|CEX_VERIFY|OK|$PKG" \
    "$(run CEX_VERIFY "$PKG" '' '' '' '' "$ADM")"
check "attest sealed package" "SUCCESS|CEX_ATTESTED" \
    "$(run CEX_ATTEST "$PKG" 'reviewed' '' '' '' "$ADM")"
check_contains "list packages by status" "$PKG" \
    "$(run CEX_PACKAGE_LIST ATTESTED 50 0 '' '' "$ADM")"
check_contains "compliance summary" "CEX_SUMMARY|1|0|0|1|0" \
    "$(run CEX_SUMMARY '' '' '' '' '' "$ADM")"
check "revoke package" "SUCCESS|CEX_REVOKED" \
    "$(run CEX_REVOKE "$PKG" 'superseded' '' '' '' "$ADM")"
check "missing package rejected" "ERROR|NOT_FOUND" \
    "$(run CEX_PACKAGE_GET 'CEX_MISSING' '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run CEX_SUMMARY '' '' '' '' '' "$USR")"
check "compliance export audit rows recorded" "6" \
    "$(q "SELECT COUNT(*) FROM compliance_export_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('PACKAGE_SAVE','ITEM_ADD','SEAL','ATTEST','REVOKE','AUTHZ_DENIED');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
