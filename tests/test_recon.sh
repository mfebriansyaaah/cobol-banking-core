#!/bin/bash
# Reconciliation reporting suite (Sprint 1 slice 7).
BIN="./cobol/bin/main_logic"; . ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'; passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }
ADM="recon_admin@test.com"; USR="recon_user@test.com"; CUST="recon_cust@test.com"
cleanup() { q "DELETE FROM recon_audit WHERE actor_email IN ('$ADM','$USR'); DELETE FROM recon_note WHERE finding_id IN (SELECT finding_id FROM reconciliation_findings WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='$CUST'))); DELETE FROM reconciliation_findings WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='$CUST')); DELETE FROM reconciliation_runs WHERE actor_email='$ADM'; DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='$CUST'); DELETE FROM users WHERE email IN ('$ADM','$USR','$CUST');"; }
setup() { cleanup; q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (1007,'$ADM','x','Recon Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),(1008,'$USR','x','Recon User','1990-01-01','VERIFIED','USER'),(1009,'$CUST','x','Recon Customer','1990-01-01','VERIFIED','USER') ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED'; INSERT INTO accounts (user_id,currency_id,balance,status) SELECT 1009,currency_id,0,'ACTIVE' FROM currencies WHERE iso_code='IDR' LIMIT 1 ON DUPLICATE KEY UPDATE status='ACTIVE'; INSERT INTO reconciliation_runs (trigger_src,actor_email,status,mismatch_count) VALUES ('MANUAL','$ADM','MISMATCH',1); SET @rid=LAST_INSERT_ID(); INSERT INTO reconciliation_findings (run_id,account_id,balance,ledger_sum,status) SELECT @rid, a.account_id, 10, 5, 'OPEN' FROM accounts a WHERE a.user_id=1009;"; }
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1008;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"; echo "  RECONCILIATION REPORTING SUITE (PHASE 1)"; echo "======================================================================"; setup
FIND="$(q "SELECT finding_id FROM reconciliation_findings WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id=1009) LIMIT 1;")"
check "add recon note" "SUCCESS|RECON_NOTE_ADDED" "$(run RECON_NOTE_ADD "$FIND" 'investigating' '' '' '' "$ADM")"
check_contains "list recon notes" "investigating" "$(run RECON_NOTE_LIST "$FIND" 50 0 '' '' "$ADM")"
check "assign finding" "SUCCESS|RECON_ASSIGNED" "$(run RECON_ASSIGN "$FIND" "$USR" '' '' '' "$ADM")"
check_contains "summary" "RECON_SUMMARY" "$(run RECON_SUMMARY '' '' '' '' '' "$ADM")"
check_contains "aging" "$FIND" "$(run RECON_AGING OPEN 50 0 '' '' "$ADM")"
check_contains "trend" "RECON_TREND" "$(run RECON_TREND 7 '' '' '' '' "$ADM")"
check_contains "export" "$FIND" "$(run RECON_EXPORT OPEN CSV '' '' '' "$ADM")"
check "set recon SLA" "SUCCESS|RECON_SLA_SET" "$(run RECON_SLA_SET 12 1 '' '' '' "$ADM")"
check "get recon SLA" "SUCCESS|RECON_SLA|12:1" "$(run RECON_SLA_GET '' '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run RECON_SUMMARY '' '' '' '' '' "$USR")"
check "recon audit rows recorded" "4" "$(q "SELECT COUNT(*) FROM recon_audit WHERE actor_email IN ('$ADM','$USR');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
