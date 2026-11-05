#!/usr/bin/env bash
# Safety tests for scripts/ci/restore_db_snapshot.sh (CI-008B). No database needed.
# Fake `mysql` earlier in PATH records every invocation; restore runs fully
# offline with a real gzip snapshot and a fake migrate script. Asserts:
#   1. Local run without CI=true/GITHUB_ACTIONS=true/ALLOW_CI_DB=1 is refused
#      BEFORE any mysql call (exit 2).
#   2. System databases are refused even with ALLOW_CI_DB=1 (exit 2).
#   3. An empty DB_NAME is refused (exit 2).
#   4. A missing snapshot file fails (exit 1) with no DROP attempted.
#   5. Happy path (CI=true): DROP then CREATE then restore, table count
#      matches the snapshot file, schema_migrations non-empty,
#      migrate --check green, password absent from output.
#   6. A failing `migrate.sh --check` fails the restore (no silent use).
# Usage: tests/scripts/test_db_snapshot_restore_guard.sh
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RESTORE="$ROOT/scripts/ci/restore_db_snapshot.sh"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok - $1"; }
not_ok() { FAIL=$((FAIL + 1)); echo "not ok - $1"; }

make_fakes() {
    local dir="$1"
    mkdir -p "$dir"
    cat > "$dir/mysql" <<'EOF'
#!/usr/bin/env bash
# Fake mysql: log every call; answer count queries with canned numbers
# from $FAKE_TABLES / $FAKE_MIGS.
echo "CALL: $*" >> "$FAKE_LOG"
for a in "$@"; do
    case "$a" in
        *"information_schema.tables"*) echo "$FAKE_TABLES"; exit 0 ;;
        *"schema_migrations"*) echo "$FAKE_MIGS"; exit 0 ;;
    esac
done
# Consume any piped dump so gunzip never sees SIGPIPE (real mysql reads stdin).
cat > /dev/null
exit 0
EOF
    chmod +x "$dir/mysql"
}

make_migrate() {
    # $1 = dir, $2 = exit code
    printf '#!/usr/bin/env bash\nexit %s\n' "$2" > "$1/migrate_fake.sh"
    chmod +x "$1/migrate_fake.sh"
}

make_snapshot() {
    # $1 = dir, $2 = table count -> $1/snap.sql.gz (+ schema file with N tables)
    local dir="$1" n="$2" i
    : > "$dir/schema.sql"
    for i in $(seq 1 "$n"); do
        printf 'CREATE TABLE t%s (id INT);\n' "$i" >> "$dir/schema.sql"
    done
    gzip -c "$dir/schema.sql" > "$dir/snap.sql.gz"
}

run_restore() {
    # remaining args are VAR=value env assignments; snapshot path is $1
    local snap="$1"
    shift
    env "$@" PATH="$FAKE_BIN:$PATH" bash "$RESTORE" "$snap"
}

# --- case 1: local run without CI flags is refused before any mysql call ---
FAKE1="$(mktemp -d "${TMPDIR:-/tmp}/snap-restore.XXXXXX")"
make_fakes "$FAKE1"
make_migrate "$FAKE1" 0
make_snapshot "$FAKE1" 3
export FAKE_LOG="$FAKE1/calls.log" FAKE_BIN="$FAKE1" FAKE_TABLES=3 FAKE_MIGS=5
# --- case 1: local run without CI flags is refused before any mysql call ---
# NOTE: CI=true / GITHUB_ACTIONS=true are scrubbed: GitHub runners always
# export CI=true, so without this the "local" case would silently inherit it.
: > "$FAKE_LOG"
if (
    unset CI GITHUB_ACTIONS
    DB_NAME="cobol_db" DB_HOST="h" DB_PORT="3306" \
    DB_MIGRATE_USER="u" DB_MIGRATE_PASS="p" \
    MIGRATE_SH="$FAKE1/migrate_fake.sh" SCHEMA_SNAPSHOT="$FAKE1/schema.sql" \
    run_restore "$FAKE1/snap.sql.gz" >/dev/null 2>&1
); then
    not_ok "local run without CI flags is refused"
else
    rc=$?
    if [ "$rc" = "2" ] && ! grep -q "CALL:" "$FAKE_LOG" 2>/dev/null; then
        ok "local run refused before any mysql call (exit 2)"
    else
        not_ok "local run refused before any mysql call (rc=$rc)"
    fi
fi

# --- case 2: system database refused even with ALLOW_CI_DB=1 ---
export FAKE_LOG="$FAKE1/calls.log"
: > "$FAKE_LOG"
if DB_NAME="mysql" DB_HOST="h" DB_PORT="3306" \
    DB_MIGRATE_USER="u" DB_MIGRATE_PASS="p" ALLOW_CI_DB=1 \
    MIGRATE_SH="$FAKE1/migrate_fake.sh" SCHEMA_SNAPSHOT="$FAKE1/schema.sql" \
    run_restore "$FAKE1/snap.sql.gz" >/dev/null 2>&1; then
    not_ok "system DB_NAME=mysql is refused"
else
    rc=$?
    if [ "$rc" = "2" ] && ! grep -q "CALL:" "$FAKE_LOG" 2>/dev/null; then
        ok "system DB refused before any mysql call (exit 2)"
    else
        not_ok "system DB refused before any mysql call (rc=$rc)"
    fi
fi

# --- case 3: empty DB name refused ---
if DB_NAME="" DB_HOST="h" DB_PORT="3306" \
    DB_MIGRATE_USER="u" DB_MIGRATE_PASS="p" ALLOW_CI_DB=1 \
    MIGRATE_SH="$FAKE1/migrate_fake.sh" SCHEMA_SNAPSHOT="$FAKE1/schema.sql" \
    run_restore "$FAKE1/snap.sql.gz" >/dev/null 2>&1; then
    not_ok "empty DB_NAME is refused"
else
    rc=$?
    if [ "$rc" = "2" ]; then
        ok "empty DB_NAME refused (exit 2)"
    else
        not_ok "empty DB_NAME refused (rc=$rc)"
    fi
fi

# --- case 4: missing snapshot file fails with no DROP ---
: > "$FAKE_LOG"
if DB_NAME="cobol_db" DB_HOST="h" DB_PORT="3306" \
    DB_MIGRATE_USER="u" DB_MIGRATE_PASS="p" ALLOW_CI_DB=1 \
    MIGRATE_SH="$FAKE1/migrate_fake.sh" SCHEMA_SNAPSHOT="$FAKE1/schema.sql" \
    run_restore "$FAKE1/does-not-exist.sql.gz" >/dev/null 2>&1; then
    not_ok "missing snapshot file fails"
else
    rc=$?
    if [ "$rc" != "0" ] && ! grep -q "DROP DATABASE" "$FAKE_LOG" 2>/dev/null; then
        ok "missing snapshot fails (rc=$rc) with no DROP attempted"
    else
        not_ok "missing snapshot fails with no DROP attempted (rc=$rc)"
    fi
fi

# --- case 5: happy path restores, verifies, and hides the password ---
OUT5="$FAKE1/happy.out"
: > "$FAKE_LOG"
if DB_NAME="cobol_db" DB_HOST="h" DB_PORT="3306" \
    DB_MIGRATE_USER="u" DB_MIGRATE_PASS="s3cret-pw" ALLOW_CI_DB=0 CI="true" \
    MIGRATE_SH="$FAKE1/migrate_fake.sh" SCHEMA_SNAPSHOT="$FAKE1/schema.sql" \
    run_restore "$FAKE1/snap.sql.gz" >"$OUT5" 2>&1; then
    drop_line="$(grep -n "DROP DATABASE" "$FAKE_LOG" | head -1 | cut -d: -f1)"
    create_line="$(grep -n "CREATE DATABASE" "$FAKE_LOG" | head -1 | cut -d: -f1)"
    if [ -n "$drop_line" ] && [ -n "$create_line" ] && [ "$drop_line" -lt "$create_line" ] \
        && grep -q "3 tables" "$OUT5" && ! grep -q "s3cret-pw" "$OUT5"; then
        ok "happy path: DROP then CREATE, counts verified, password hidden"
    else
        not_ok "happy path restores and verifies (see $OUT5)"
    fi
else
    not_ok "happy path exits 0 (rc=$?)"
fi

# --- case 6: failing migrate --check fails the restore ---
FAKE6="$(mktemp -d "${TMPDIR:-/tmp}/snap-restore.XXXXXX")"
make_fakes "$FAKE6"
make_migrate "$FAKE6" 1
make_snapshot "$FAKE6" 3
export FAKE_LOG="$FAKE6/calls.log" FAKE_BIN="$FAKE6" FAKE_TABLES=3 FAKE_MIGS=5
: > "$FAKE_LOG"
if DB_NAME="cobol_db" DB_HOST="h" DB_PORT="3306" \
    DB_MIGRATE_USER="u" DB_MIGRATE_PASS="p" CI="true" \
    MIGRATE_SH="$FAKE6/migrate_fake.sh" SCHEMA_SNAPSHOT="$FAKE6/schema.sql" \
    run_restore "$FAKE6/snap.sql.gz" >/dev/null 2>&1; then
    not_ok "failing migrate --check fails the restore"
else
    ok "failing migrate --check fails the restore (rc=$?)"
fi

rm -rf "$FAKE1" "$FAKE6"
echo "=== DB SNAPSHOT RESTORE: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
