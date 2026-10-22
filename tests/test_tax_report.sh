#!/bin/bash
BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'; passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }
ADM="tax_admin@test.com"; USR="tax_user@test.com"
cleanup() {
    q "DELETE FROM tax_report_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM tax_report WHERE created_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1370,'$ADM','x','TAX Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1371,'$USR','x','TAX User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  TAX REPORT SUITE (PHASE 1)"
echo "======================================================================"
setup
check "create tax report" "SUCCESS|TAX_CREATED" \
    "$(run TAX_CREATE TAX1 VAT 2026-09 1000.00 USD "$ADM")"
RID=$(q "SELECT id FROM tax_report WHERE created_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "get tax report" "TAX_REPORT|$RID" \
    "$(run TAX_GET "$RID" '' '' '' '' "$ADM")"
check_contains "list tax reports" "$RID" \
    "$(run TAX_LIST DRAFT 50 0 '' '' "$ADM")"
check "file tax report" "SUCCESS|TAX_FILED" \
    "$(run TAX_FILE "$RID" '' '' '' '' "$ADM")"
check "pay tax report" "SUCCESS|TAX_PAID" \
    "$(run TAX_PAY "$RID" '' '' '' '' "$ADM")"
check_contains "tax summary" "TAX_SUMMARY|" \
    "$(run TAX_SUMMARY '' '' '' '' '' "$ADM")"
check "missing tax report rejected" "ERROR|NOT_FOUND" \
    "$(run TAX_GET 999999 '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run TAX_SUMMARY '' '' '' '' '' "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
