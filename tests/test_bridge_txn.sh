#!/bin/bash
# Bridge transaction suite: a SQL_BEGIN while a transaction is still open
# must roll the leaked work back rather than abandoning it (the next START
# TRANSACTION would otherwise implicitly commit it). A C harness drives the
# real bridge against a scratch TEMPORARY table, so no real schema is
# touched. Needs the database like every other shell suite (no skipping).
# Usage: ./tests/test_bridge_txn.sh

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"
export DB_USER DB_PASS DB_NAME

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
echo "  BRIDGE TRANSACTION SUITE"
echo "======================================================================"

cat > "$TMP/harness.c" <<'C'
#include <stdio.h>
#include <string.h>

void SET_QUERY(char *query);
void GET_RESULT(char *result);
void SQL_EXECUTE(void);
void SQL_BEGIN(void);
void SQL_COMMIT(void);
void SQL_ROLLBACK(void);

static char R[16384];

static void q(const char *sql) {
    char query[1024];
    memset(query, ' ', sizeof(query));
    size_t n = strlen(sql);
    if (n > sizeof(query)) n = sizeof(query);
    memcpy(query, sql, n);
    SET_QUERY(query);
    SQL_EXECUTE();
    GET_RESULT(R);
}

int main(void) {
    q("CREATE TEMPORARY TABLE IF NOT EXISTS bridge_reentry (x INT PRIMARY KEY)");
    printf("setup=%s\n", R);

    /* Leaked work: insert inside txn 1, then BEGIN again without closing it.
     * Correct behaviour rolls the insert back; abandoning it would let the
     * new START TRANSACTION commit it implicitly. */
    SQL_BEGIN();
    q("INSERT INTO bridge_reentry VALUES (1)");
    SQL_BEGIN();
    GET_RESULT(R);
    printf("rebegin=%s\n", R);
    SQL_ROLLBACK();
    q("SELECT COUNT(*) FROM bridge_reentry");
    printf("leaked=%s\n", R);

    /* Sanity: a normal begin/insert/commit round-trip still persists. */
    SQL_BEGIN();
    q("INSERT INTO bridge_reentry VALUES (2)");
    SQL_COMMIT();
    q("SELECT COUNT(*) FROM bridge_reentry");
    printf("committed=%s\n", R);

    /* Pin existing behaviour: closing nothing reports NO_TRANSACTION. */
    SQL_COMMIT();
    GET_RESULT(R);
    printf("no_txn=%s\n", R);

    q("DROP TEMPORARY TABLE IF EXISTS bridge_reentry");
    return 0;
}
C

build_rc=0
gcc -std=c11 -Wall -Wextra -g -o "$TMP/harness" "$TMP/harness.c" \
    cobol/src/sql_bridge.c -L/usr/lib/x86_64-linux-gnu -lmysqlclient \
    2>"$TMP/cc.err" || build_rc=1
check "txn harness builds cleanly" "0" "$build_rc"
[ "$build_rc" -eq 0 ] || { sed -n '1,10p' "$TMP/cc.err"; echo "cannot run the harness"; exit 1; }

OUT=$("$TMP/harness" 2>/dev/null)
# GET_RESULT space-pads to its full field width; trim before comparing.
val() { echo "$OUT" | grep -E "^$1=" | cut -d'=' -f2 | sed 's/ *$//'; }
check "re-entry starts a transaction" "SUCCESS|BEGIN" "$(val rebegin)"
check "leaked insert rolled back" "0" "$(val leaked)"
check "normal commit persists" "1" "$(val committed)"
check "commit without begin reports NO_TRANSACTION" "ERROR|NO_TRANSACTION" "$(val no_txn)"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
