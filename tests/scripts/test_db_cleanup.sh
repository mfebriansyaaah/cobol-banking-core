#!/usr/bin/env bash
# Regression test for the full-mode DB cleanup leak (T-014/T-015).
# A successful `tests/run_all.sh full` used to leave cobol_db_test_* and
# cobol_db_shard_* databases behind: run_integration reset SHARD_DBS and
# ISOLATED_DB_CREATED to "" and installed a new EXIT trap, so the final
# cleanup saw empty lists and dropped nothing.
#
# Two layers, no database needed:
#   1. structural: exactly one EXIT trap installs cleanup_db_resources, and
#      no phase body resets the throwaway-DB lists;
#   2. runtime: the shipped cleanup_db_resources() (extracted verbatim from
#      tests/run_all.sh) drops exactly the listed databases against a fake
#      `mysql`, and never touches cobol_db.
# Usage: tests/scripts/test_db_cleanup.sh (or via tests/scripts/run.sh)
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUN_ALL="$ROOT/tests/run_all.sh"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok - $1"; }
not_ok() { FAIL=$((FAIL + 1)); echo "not ok - $1"; }

# --- 1. one top-level EXIT trap owns cleanup ---
TRAPS="$(grep -cE '^[[:space:]]*trap .*EXIT' "$RUN_ALL" || true)"
if [ "$TRAPS" = "1" ]; then
    ok "exactly one EXIT trap in run_all.sh"
else
    not_ok "exactly one EXIT trap in run_all.sh (got $TRAPS)"
fi
if grep -E '^[[:space:]]*trap .*EXIT' "$RUN_ALL" | grep -q 'cleanup_db_resources' \
    && grep -E '^[[:space:]]*trap .*EXIT' "$RUN_ALL" | grep -q 'db_lock_release' \
    && grep -E '^[[:space:]]*trap .*EXIT' "$RUN_ALL" | grep -q 'report_finalize'; then
    ok "the EXIT trap runs cleanup, lock release, and reporting"
else
    not_ok "the EXIT trap runs cleanup, lock release, and reporting"
fi

# --- 1b. no phase body resets the throwaway-DB lists ---
# Range-restricted search: allow the single top-level initialization, forbid
# resets inside run_db / run_integration / the db-shard dispatch branch.
RESETS="$(awk '
    /^run_db\(\)/ {in_db=1}
    /^run_integration\(\)/ {in_int=1}
    /^    db-shard\)/ {in_shard=1}
    /^\}$/ {in_db=0; in_int=0}
    /^        ;;$/ {in_shard=0}
    (in_db || in_int || in_shard) && /^[[:space:]]*(SHARD_DBS|ISOLATED_DB_CREATED)=""[[:space:]]*$/ {print FILENAME":"FNR": "$0}
' "$RUN_ALL")"
if [ -z "$RESETS" ]; then
    ok "no phase body resets the throwaway-DB lists"
else
    not_ok "no phase body resets the throwaway-DB lists"
    printf '%s\n' "$RESETS" | sed 's/^/  # /'
fi

# --- 2. runtime: real cleanup_db_resources() against fake mysql ---
WORK="$(mktemp -d "${TMPDIR:-/tmp}/db-cleanup.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
MYSQL_LOG="$WORK/mysql.log"
: > "$MYSQL_LOG"
cat > "$WORK/bin/mysql" <<'EOF'
#!/usr/bin/env bash
# Fake mysql: record every -e statement, succeed at everything.
printf '%s\n' "$@" >> "$MYSQL_LOG"
exit 0
EOF
chmod +x "$WORK/bin/mysql"
export MYSQL_LOG

# Extract the shipped function verbatim and run it with test state.
awk '/^cleanup_db_resources\(\) \{/,/^\}$/' "$RUN_ALL" > "$WORK/cleanup.sh"
cat > "$WORK/driver.sh" <<'EOF'
set -u
mysql_admin() { "$WORK_BIN/mysql" ${DB_FAKE_ARGS:-} "$@" ; }
SHARD_DBS="cobol_db_shard_0_4242 cobol_db_shard_1_4242"
ISOLATED_DB_CREATED="cobol_db_test_4242"
# shellcheck disable=SC1091
. "$WORK_DIR/cleanup.sh"
cleanup_db_resources
EOF
WORK_BIN="$WORK/bin" WORK_DIR="$WORK" PATH="$WORK/bin:$PATH" bash "$WORK/driver.sh"

for db in cobol_db_test_4242 cobol_db_shard_0_4242 cobol_db_shard_1_4242; do
    if grep -q "DROP DATABASE.*\`$db\`" "$MYSQL_LOG"; then
        ok "cleanup drops $db"
    else
        not_ok "cleanup drops $db"
    fi
done
if grep 'DROP DATABASE' "$MYSQL_LOG" | grep -v 'cobol_db_\(test_\|shard_\)' | grep -q .; then
    not_ok "cleanup never touches cobol_db"
    grep 'DROP DATABASE' "$MYSQL_LOG" | grep -v 'cobol_db_\(test_\|shard_\)' | sed 's/^/  # /'
else
    ok "cleanup never touches cobol_db"
fi
# Idempotent: a second run with empty lists issues no DROP at all.
: > "$MYSQL_LOG"
cat > "$WORK/driver_empty.sh" <<'EOF'
set -u
mysql_admin() { "$WORK_BIN/mysql" ${DB_FAKE_ARGS:-} "$@" ; }
SHARD_DBS=""
ISOLATED_DB_CREATED=""
# shellcheck disable=SC1091
. "$WORK_DIR/cleanup.sh"
cleanup_db_resources
EOF
WORK_BIN="$WORK/bin" WORK_DIR="$WORK" PATH="$WORK/bin:$PATH" bash "$WORK/driver_empty.sh"
if grep -q 'DROP DATABASE' "$MYSQL_LOG"; then
    not_ok "cleanup with empty lists issues no DROP"
else
    ok "cleanup with empty lists issues no DROP"
fi

echo "=== DB CLEANUP: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -ne 0 ]; then exit 1; fi
echo "=== DB CLEANUP GREEN ==="
exit 0
