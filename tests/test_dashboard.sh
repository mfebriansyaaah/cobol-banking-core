#!/bin/bash
# Operational dashboard suite (Phase 1, Sprint 1 slice 11).
BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
ADM="dsh_admin@test.com"; USR="dsh_user@test.com"
cleanup() { q "DELETE FROM users WHERE email IN ('$ADM','$USR');"; }
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1070,'$ADM','x','DSH Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1071,'$USR','x','DSH User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1071;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  OPERATIONAL DASHBOARD SUITE (PHASE 1)"
echo "======================================================================"
setup
check_contains "overview" "SUCCESS|DSH_OVERVIEW|" "$(run DSH_OVERVIEW '' '' '' '' '' "$ADM")"
check_contains "payments" "SUCCESS|DSH_PAYMENTS|" "$(run DSH_PAYMENTS '' '' '' '' '' "$ADM")"
check_contains "recon" "SUCCESS|DSH_RECON|" "$(run DSH_RECON '' '' '' '' '' "$ADM")"
check_contains "disputes" "SUCCESS|DSH_DISPUTES|" "$(run DSH_DISPUTES '' '' '' '' '' "$ADM")"
check_contains "alerts" "SUCCESS|DSH_ALERTS|" "$(run DSH_ALERTS '' '' '' '' '' "$ADM")"
check_contains "outbox" "SUCCESS|DSH_OUTBOX|" "$(run DSH_OUTBOX '' '' '' '' '' "$ADM")"
check_contains "reports" "SUCCESS|DSH_REPORTS|" "$(run DSH_REPORTS '' '' '' '' '' "$ADM")"
check_contains "imports" "SUCCESS|DSH_IMPORTS|" "$(run DSH_IMPORTS '' '' '' '' '' "$ADM")"
check_contains "accounts" "SUCCESS|DSH_ACCOUNTS|" "$(run DSH_ACCOUNTS '' '' '' '' '' "$ADM")"
check_contains "fees" "SUCCESS|DSH_FEES|" "$(run DSH_FEES '' '' '' '' '' "$ADM")"
check_contains "policy" "SUCCESS|DSH_POLICY|" "$(run DSH_POLICY '' '' '' '' '' "$ADM")"
check_contains "cashflow" "SUCCESS|DSH_CASHFLOW|" "$(run DSH_CASHFLOW 2026-10-01 2026-10-31 IDR '' '' "$ADM")"
check "bad date rejected" "ERROR|INVALID_INPUT" "$(run DSH_CASHFLOW 2026-13-01 2026-10-31 IDR '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run DSH_OVERVIEW '' '' '' '' '' "$USR")"
check "unknown action rejected" "ERROR|INVALID_ACTION" "$(run DSH_MISSING '' '' '' '' '' "$ADM")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
