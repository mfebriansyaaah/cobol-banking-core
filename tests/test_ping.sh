#!/bin/bash
# Deep-health action: PING confirms the COBOL core reaches the database.
# Usage: ./tests/test_ping.sh
BIN="./cobol/bin/main_logic"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'; passed=0; failed=0
run() { printf "%s|%s|%s|%s|%s\n" "$1" "$2" "$3" "$4" "$5" > input.txt; "$BIN" >/dev/null 2>&1; cat output.txt; }
check() { if [ "$2" = "$3" ]; then echo -e "${GREEN}PASS${NC} $1"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $1 (expected [$2] got [$3])"; failed=$((failed+1)); fi; }
echo "======================================================================"
echo "  PING / DEEP HEALTH SUITE"
echo "======================================================================"
check "ping reaches DB" "SUCCESS|PONG" "$(run PING "" "" "")"
check "unknown action still invalid" "ERROR|INVALID_ACTION" "$(run ZZZ "" "" "")"

# Connection settings come from the environment, not the source.
printf 'PING\n' > input.txt
out=$(DB_NAME=nonexistent_$$ "$BIN" >/dev/null 2>&1; cat output.txt)
check "DB settings read from the environment" "ERROR|DB_DOWN" "$out"

# Production refuses to connect with the development credentials, and says so
# distinctly from an unreachable database (fail-closed backstop behind the
# gateway's startup guard).
printf 'PING\n' > input.txt
out=$(NODE_ENV=production "$BIN" >/dev/null 2>&1; cat output.txt)
check "production refuses dev DB credentials" "ERROR|DB_CONFIG_INSECURE" "$out"
printf 'PING\n' > input.txt
out=$(NODE_ENV=production DB_USER=app_rw "$BIN" >/dev/null 2>&1; cat output.txt)
check "production refuses a missing DB password" "ERROR|DB_CONFIG_INSECURE" "$out"
printf 'PING\n' > input.txt
out=$(NODE_ENV=production DB_USER=app_rw DB_PASS=strongsecret DB_NAME=cobol_db DB_HOST=localhost "$BIN" >/dev/null 2>&1; cat output.txt)
check "production with explicit credentials reaches the DB" "ERROR|DB_DOWN" "$out"
printf 'PING\n' > input.txt
out=$(NODE_ENV=development "$BIN" >/dev/null 2>&1; cat output.txt)
check "development keeps the local defaults" "SUCCESS|PONG" "$out"
echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
