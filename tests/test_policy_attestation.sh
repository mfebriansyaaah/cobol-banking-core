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
ADM="pat_admin@test.com"; USR="pat_user@test.com"
cleanup() {
    q "DELETE FROM policy_attestation_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM policy_attestation WHERE created_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1380,'$ADM','x','PAT Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1381,'$USR','x','PAT User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  POLICY ATTESTATION SUITE (PHASE 1)"
echo "======================================================================"
setup
check "create attestation" "SUCCESS|PAT_CREATED" \
    "$(run PAT_CREATE PAT_TEST 'Security policy' "$ADM" 2026-12-31 '' "$ADM")"
check_contains "list attestations" "PAT_TEST" \
    "$(run PAT_LIST 50 0 '' '' '' "$ADM")"
check "attest policy" "SUCCESS|PAT_ATTESTED" \
    "$(run PAT_ATTEST PAT_TEST '' '' '' '' "$ADM")"
check_contains "attestation summary" "PAT_SUMMARY|" \
    "$(run PAT_SUMMARY '' '' '' '' '' "$ADM")"
check "missing attestation rejected" "ERROR|INVALID_STATUS" \
    "$(run PAT_ATTEST PAT_MISSING '' '' '' '' "$ADM")" 2>/dev/null || true
# missing handled by attest status; use get not available, so check summary instead
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run PAT_SUMMARY '' '' '' '' '' "$USR")"
check "policy attestation audit rows recorded" "3" \
    "$(q "SELECT COUNT(*) FROM policy_attestation_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('CREATE','ATTEST','AUTHZ_DENIED');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
