#!/usr/bin/env bash
# Regression test for isolated/shard worker databases losing migration-seeded
# reference data (T-051 finding).
#
# Worker DBs are cloned from a template dump. A schema-only dump (--no-data)
# plus a fresh seed silently dropped reference rows that migrations had
# inserted (gl_account chart, ref_type/ref_value, password_blocklist, ...),
# so suites and integration flows behaved differently isolated vs direct
# (trade_finance_lc_flow failed only under isolation: ACCOUNT_NOT_FOUND).
#
# This test pins the fix without a database:
#   1. structural: dump_template_schema must not pass --no-data and must not
#      re-append the ledger as a separate step (full-data dump includes it);
#   2. runtime: the shipped function invoked against a fake mysqldump must
#      request a full dump (routines + triggers, no --no-data) of exactly
#      the template database.
# Usage: tests/scripts/test_isolated_db_data.sh (or via tests/scripts/run.sh)
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok - $1"; }
not_ok() { FAIL=$((FAIL + 1)); echo "not ok - $1"; }

FUNC_SRC="$(sed -n '/^dump_template_schema() {/,/^}/p' "$ROOT/tests/run_all.sh")"
if [ -z "$FUNC_SRC" ]; then
    not_ok "dump_template_schema found in run_all.sh"
else
    ok "dump_template_schema found in run_all.sh"
fi

if printf '%s\n' "$FUNC_SRC" | grep -q -- '--no-data'; then
    not_ok "template dump is full-data (no --no-data)"
else
    ok "template dump is full-data (no --no-data)"
fi

if printf '%s\n' "$FUNC_SRC" | grep -q 'schema_migrations.*>>'; then
    not_ok "no separate ledger append (full dump includes it)"
else
    ok "no separate ledger append (full dump includes it)"
fi

# --- runtime against a fake mysqldump (no database needed) ---
WORK="$(mktemp -d "${TMPDIR:-/tmp}/isolated-db.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
MYSQLDUMP_LOG="$WORK/mysqldump.args"
export MYSQLDUMP_LOG
cat > "$WORK/bin/mysqldump" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$MYSQLDUMP_LOG"
echo "-- fake dump"
exit 0
EOF
chmod +x "$WORK/bin/mysqldump"

OUT="$(ISOLATED_DB_CREATED=1 FUNC_SRC="$FUNC_SRC" MYSQLDUMP_LOG="$MYSQLDUMP_LOG" TMPDIR="$WORK" PATH="$WORK/bin:$PATH" bash -c '
set -u
DB_NAME=ignoreme
mysql_admin() { echo "unexpected mysql_admin call" >&2; return 1; }
eval "$FUNC_SRC"
dump_template_schema "cobol_db_template_xyz" 2>/dev/null
')"
RC=$?
DUMP_PATH="$(printf '%s\n' "$OUT" | tail -1)"
if [ "$RC" = "0" ] && [ -f "$DUMP_PATH" ] && grep -q 'fake dump' "$DUMP_PATH"; then
    ok "dump function produces a dump file"
else
    not_ok "dump function produces a dump file (rc=$RC)"
fi

ARGS="$(tr '\n' ' ' < "$MYSQLDUMP_LOG" 2>/dev/null)"
case " $ARGS " in
    *" --no-data "*) not_ok "mysqldump invoked without --no-data" ;;
    *) ok "mysqldump invoked without --no-data" ;;
esac
case " $ARGS " in
    *" --routines "*"--triggers "*"--single-transaction "*) ok "mysqldump keeps routines/triggers/consistency flags" ;;
    *) not_ok "mysqldump keeps routines/triggers/consistency flags" ;;
esac
case " $ARGS " in
    *" cobol_db_template_xyz"*) ok "mysqldump targets exactly the template database" ;;
    *) not_ok "mysqldump targets exactly the template database" ;;
esac

echo "=== ISOLATED DB DATA: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -ne 0 ]; then exit 1; fi
echo "=== ISOLATED DB DATA GREEN ==="
exit 0
