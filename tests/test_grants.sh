#!/bin/bash
# Least-privilege database guardrail (no database required). The provisioning
# script must give the application account DML only (never DDL) and the
# migration account DDL, on two distinct accounts, and migrations must support
# a separate privileged credential.
# Usage: ./tests/test_grants.sh

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected [$expected] got [$actual])"; failed=$((failed+1))
    fi
}

echo "======================================================================"
echo "  LEAST-PRIVILEGE DATABASE SUITE"
echo "======================================================================"

SQL="$(./database/grants.sh --print 2>/dev/null)"
APP_LINE="$(printf '%s\n' "$SQL" | grep -E "^GRANT .* TO 'cobol_app'" | head -1)"
MIG_LINE="$(printf '%s\n' "$SQL" | grep -E "^GRANT .* TO 'cobol_migrate'" | head -1)"

check "app grant is DML-only" \
    "GRANT SELECT, INSERT, UPDATE, DELETE ON \`cobol_db\`.* TO 'cobol_app'@'localhost';" \
    "$APP_LINE"

if printf '%s' "$APP_LINE" | grep -qE "ALL PRIVILEGES|CREATE|DROP|ALTER|GRANT OPTION"; then
    check "app grant holds no DDL" "no-ddl" "ddl: $APP_LINE"
else
    check "app grant holds no DDL" "no-ddl" "no-ddl"
fi

check "migration grant is full DDL" \
    "GRANT ALL PRIVILEGES ON \`cobol_db\`.* TO 'cobol_migrate'@'localhost';" \
    "$MIG_LINE"

APP_USER="$(printf '%s' "$APP_LINE" | grep -oE "'cobol_app'@'localhost'")"
MIG_USER="$(printf '%s' "$MIG_LINE" | grep -oE "'cobol_migrate'@'localhost'")"
[ -n "$APP_USER" ] && [ "$APP_USER" != "$MIG_USER" ] \
    && check "application and migration accounts differ" "distinct" "distinct" \
    || check "application and migration accounts differ" "distinct" "same"

if grep -q 'DB_MIGRATE_USER' database/migrate.sh; then
    check "migrations use a separate credential" "yes" "yes"
else
    check "migrations use a separate credential" "yes" "no"
fi

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
