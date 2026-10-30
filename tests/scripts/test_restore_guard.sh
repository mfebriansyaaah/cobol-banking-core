#!/usr/bin/env bash
# Safety tests for scripts/ci/restore_drill.sh. No real database needed.
# A fake `mysql` earlier in PATH records every invocation; the drill runs
# fully offline. Asserts:
#   1. RESTORE_DRILL_DB=cobol_db is refused BEFORE any DROP (exit 2, no DROP).
#   2. DB_NAME=cobol_db does not leak into the drill target: every DROP/CREATE
#      targets cobol_db_restore_drill (or the configured RESTORE_DRILL_DB).
# Usage: tests/scripts/test_restore_guard.sh
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok - $1"; }
not_ok() { FAIL=$((FAIL + 1)); echo "not ok - $1"; }

make_fake_mysql() {
    local dir="$1"
    mkdir -p "$dir"
    cat > "$dir/mysql" <<'EOF'
#!/usr/bin/env bash
# Fake mysql for restore drill tests: log every call, succeed, and answer the
# table-count query with a healthy number.
echo "CALL: $*" >> "$FAKE_LOG"
for a in "$@"; do
    case "$a" in
        *"COUNT(*) FROM information_schema.tables"*)
            echo "500"
            exit 0
            ;;
    esac
done
exit 0
EOF
    chmod +x "$dir/mysql"
}

# --- case 1: protected drill target is refused before any DROP ---
FAKE1="$(mktemp -d "${TMPDIR:-/tmp}/restore-guard.XXXXXX")"
make_fake_mysql "$FAKE1"
export FAKE_LOG="$FAKE1/calls.log"
: > "$FAKE_LOG"
if RESTORE_DRILL_DB="cobol_db" DB_HOST="192.0.2.1" PATH="$FAKE1:$PATH" \
    bash "$ROOT/scripts/ci/restore_drill.sh" >/dev/null 2>&1; then
    not_ok "protected RESTORE_DRILL_DB=cobol_db is refused"
else
    rc=$?
    if [ "$rc" = "2" ] && ! grep -q "DROP DATABASE" "$FAKE_LOG" 2>/dev/null; then
        ok "protected RESTORE_DRILL_DB=cobol_db is refused before DROP (exit 2, no DROP)"
    else
        not_ok "protected RESTORE_DRILL_DB=cobol_db is refused before DROP (rc=$rc, log below)"
        cat "$FAKE_LOG" 2>/dev/null
    fi
fi

# --- case 2: DB_NAME never becomes the drill target ---
FAKE2="$(mktemp -d "${TMPDIR:-/tmp}/restore-guard.XXXXXX")"
make_fake_mysql "$FAKE2"
export FAKE_LOG="$FAKE2/calls.log"
: > "$FAKE2/calls.log"
if DB_NAME="cobol_db" RESTORE_DRILL_DB="cobol_db_restore_drill" \
    DB_HOST="127.0.0.1" DB_PORT="3306" \
    DB_MIGRATE_USER="u" DB_MIGRATE_PASS="p" \
    PATH="$FAKE2:$PATH" \
    bash "$ROOT/scripts/ci/restore_drill.sh" >/dev/null 2>&1; then
    if grep -q "DROP DATABASE" "$FAKE2/calls.log" 2>/dev/null; then
        if grep -E "DROP DATABASE IF EXISTS \`cobol_db\`[^-]" "$FAKE2/calls.log" 2>/dev/null; then
            not_ok "drill never DROPps cobol_db (found DROP of cobol_db)"
        else
            ok "drill DROP targets only the drill database"
        fi
        if grep -q "cobol_db_restore_drill" "$FAKE2/calls.log" 2>/dev/null; then
            ok "drill operates on RESTORE_DRILL_DB"
        else
            not_ok "drill operates on RESTORE_DRILL_DB"
        fi
    else
        not_ok "drill issued a DROP (expected DROP of drill db)"
    fi
else
    not_ok "drill succeeds offline with fake mysql"
fi

rm -rf "$FAKE1" "$FAKE2"

echo "# pass=$PASS fail=$FAIL total=$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
