#!/bin/bash
# Migration tooling suite: runner is idempotent and --check detects pending work.
# Usage: ./tests/test_migrate.sh
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'; passed=0; failed=0
q(){ mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
check(){ if [ "$2" = "$3" ]; then echo -e "${GREEN}PASS${NC} $1"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $1 (expected [$2] got [$3])"; failed=$((failed+1)); fi; }
echo "======================================================================"
echo "  MIGRATION TOOLING SUITE"
echo "======================================================================"

# --- failing migration: loud, attributed, and unrecorded -----------------
TMP_MIGRATION="database/migrations/9999_zz_tmp_fail.sql"
trap 'rm -f "$TMP_MIGRATION"' EXIT
echo "THIS IS NOT VALID SQL;" > "$TMP_MIGRATION"
fail_out="$(./database/migrate.sh 2>&1; echo "rc=$?")"
if echo "$fail_out" | grep -q "migration FAILED: 9999_zz_tmp_fail" && echo "$fail_out" | grep -q "rc=[1-9]"; then
    check "failing migration aborts with attribution" "loud" "loud"
else
    check "failing migration aborts with attribution" "loud" "quiet rc=$? out: $(echo "$fail_out" | tail -2 | tr '\n' ' ')"
fi
check "failed migration is not recorded" "0" "$(q "SELECT COUNT(*) FROM schema_migrations WHERE version='9999_zz_tmp_fail';")"
rm -f "$TMP_MIGRATION"
trap - EXIT

./database/migrate.sh >/dev/null 2>&1
check "all migration files recorded" "$(ls database/migrations/*.sql | wc -l | tr -d ' ')" "$(q "SELECT COUNT(*) FROM schema_migrations;")"
check "re-run is idempotent" "no pending migrations" "$(./database/migrate.sh 2>&1 | tail -1)"
check "check passes when applied" "0" "$(./database/migrate.sh --check >/dev/null 2>&1; echo $?)"
q "DELETE FROM schema_migrations WHERE version='0001_pending_transactions_cascade';"
check "check fails when pending" "1" "$(./database/migrate.sh --check >/dev/null 2>&1; echo $?)"
./database/migrate.sh >/dev/null 2>&1
check "reapplied after pending" "1" "$(q "SELECT COUNT(*) FROM schema_migrations WHERE version='0001_pending_transactions_cascade';")"
check "check green after apply" "0" "$(./database/migrate.sh --check >/dev/null 2>&1; echo $?)"

# --- every statement must be re-runnable (static guard) -------------------
# migrate.sh replays a whole file on retry, so no statement may fail on an
# already-applied object. Allowed exception: the atomic single-statement
# DROP+ADD PRIMARY KEY rewrites (0015, 0019, 0026), and CREATE TRIGGER
# paired with a same-file DROP TRIGGER IF NOT EXISTS (0030); re-running
# those converges (or, for 0015/0019, fails loudly at parse time without
# touching data — recovery is re-recording the version, see loop below).
guard_bad=""
for f in database/migrations/*.sql; do
    v="$(basename "$f")"
    case "$v" in 9999_*) continue;; esac
    body="$(grep -vE '^\s*(--|#|$)' "$f")"
    # ADD COLUMN / ADD INDEX / ADD UNIQUE need IF NOT EXISTS, except the
    # atomic PK-rewrite pair in 0015/0019 (parse-time failure, no corruption).
    case "$v" in 0015_*|0019_*) ;;
    *)
        while IFS= read -r hit; do
            [ -n "$hit" ] && guard_bad="${guard_bad}${f}:${hit}"$'\n'
        done < <(echo "$body" | grep -nE 'ADD (COLUMN|INDEX|UNIQUE)( |$)' | grep -v 'IF NOT EXISTS' || true)
        ;;
    esac
    # DROP COLUMN / DROP FOREIGN KEY / DROP INDEX / DROP KEY / DROP TABLE need IF EXISTS.
    while IFS= read -r hit; do
        [ -n "$hit" ] && guard_bad="${guard_bad}${f}:${hit}"$'\n'
    done < <(echo "$body" | grep -nE 'DROP (COLUMN|FOREIGN KEY|INDEX|KEY|TABLE)( |$)' | grep -v 'IF EXISTS' || true)
    # DROP PRIMARY KEY only inside the atomic single-statement rewrites.
    case "$v" in 0015_*|0019_*|0026_*) ;;
    *)
        while IFS= read -r hit; do
            [ -n "$hit" ] && guard_bad="${guard_bad}${f}:${hit}"$'\n'
        done < <(echo "$body" | grep -n 'DROP PRIMARY KEY' || true)
        ;;
    esac
    # Plain ADD CONSTRAINT needs IF NOT EXISTS, or (FOREIGN KEY only) a
    # paired DROP FOREIGN KEY IF EXISTS for the same name in the same file.
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        if ! printf '%s' "$line" | grep -q 'IF NOT EXISTS'; then
            name="$(printf '%s' "$line" | grep -oE 'ADD CONSTRAINT [A-Za-z0-9_]+' | awk '{print $3}')"
            if printf '%s' "$line" | grep -q 'FOREIGN KEY'; then
                echo "$body" | grep -q "DROP FOREIGN KEY IF EXISTS $name" || guard_bad="${guard_bad}${f}:${line}"$'\n'
            else
                guard_bad="${guard_bad}${f}:${line}"$'\n'
            fi
        fi
    done < <(echo "$body" | grep -n 'ADD CONSTRAINT ' || true)
    # CREATE TRIGGER needs IF NOT EXISTS or a paired DROP TRIGGER IF EXISTS.
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        if ! printf '%s' "$line" | grep -q 'IF NOT EXISTS'; then
            name="$(printf '%s' "$line" | grep -oE 'CREATE TRIGGER [A-Za-z0-9_]+' | awk '{print $3}')"
            echo "$body" | grep -q "DROP TRIGGER IF EXISTS $name" || guard_bad="${guard_bad}${f}:${line}"$'\n'
        fi
    done < <(echo "$body" | grep -n 'CREATE TRIGGER' || true)
    # CREATE TABLE / CREATE INDEX need IF NOT EXISTS; INSERT needs IGNORE;
    # UPDATE needs WHERE (convergent re-run); DELETE is forbidden outright.
    while IFS= read -r hit; do
        [ -n "$hit" ] && guard_bad="${guard_bad}${f}:${hit}"$'\n'
    done < <(echo "$body" | grep -nE 'CREATE (TABLE|INDEX) ' | grep -v 'IF NOT EXISTS' || true)
    while IFS= read -r hit; do
        [ -n "$hit" ] && guard_bad="${guard_bad}${f}:${hit}"$'\n'
    done < <(echo "$body" | grep -nE 'INSERT INTO ' | grep -v 'INSERT IGNORE' || true)
    while IFS= read -r hit; do
        [ -n "$hit" ] && guard_bad="${guard_bad}${f}:${hit}"$'\n'
    done < <(echo "$body" | grep -nE '^ *(UPDATE|DELETE) ' | grep -v ' WHERE ' || true)
done
check "all DDL guarded for resume" "" "$guard_bad"

# --- resume after a mid-file crash ---------------------------------------
# A scratch migration with guarded DDL plus seed rows: apply only its first
# statement (simulating a crash before the version row is recorded), then
# migrate.sh must converge instead of failing on the half-applied file.
rm -f database/migrations/9999_zz_tmp_*.sql
TMP_RESUME="database/migrations/9999_zz_tmp_resume.sql"
cat > "$TMP_RESUME" <<'EOF'
CREATE TABLE IF NOT EXISTS _tmp_resume (id INT PRIMARY KEY, v INT NULL);
ALTER TABLE _tmp_resume ADD COLUMN IF NOT EXISTS w INT NULL, ADD INDEX IF NOT EXISTS idx_w (w);
INSERT IGNORE INTO _tmp_resume (id, v) VALUES (1, 1), (2, 2);
EOF
q "DROP TABLE IF EXISTS _tmp_resume; DELETE FROM schema_migrations WHERE version='9999_zz_tmp_resume';"
q "CREATE TABLE IF NOT EXISTS _tmp_resume (id INT PRIMARY KEY, v INT NULL);"
./database/migrate.sh >/dev/null 2>&1; rc=$?
check "resume converges after partial apply" "0" "$rc"
check "resume records the version" "1" "$(q "SELECT COUNT(*) FROM schema_migrations WHERE version='9999_zz_tmp_resume';")"
check "resume finishes the schema" "w" "$(q "SELECT COLUMN_NAME FROM information_schema.columns WHERE table_schema='$DB_NAME' AND table_name='_tmp_resume' AND column_name='w';")"
check "resume applies remaining rows" "2" "$(q "SELECT COUNT(*) FROM _tmp_resume;")"
q "DROP TABLE IF EXISTS _tmp_resume; DELETE FROM schema_migrations WHERE version='9999_zz_tmp_resume';"
rm -f "$TMP_RESUME"

# --- every recorded migration re-applies cleanly -------------------------
# Simulates "crash after DDL, before the version row": delete one version
# row at a time and require migrate.sh --only <version> to converge instead
# of failing on already-applied objects (--only skips the per-iteration scan
# of every migration file, which made this loop O(n^2)). Each iteration
# restores the version row afterwards so one genuine failure cannot cascade
# into the next, and the outcome is aggregated into a single assertion so
# adding a migration does not change this suite's count. Excluded by design: 0007 drops the live FX
# table (its re-run target is a pre-FX schema); 0011 narrows an ENUM and
# 0015/0019 rewrite the primary key of an AUTO_INCREMENT table in one
# atomic statement — re-applying those fails at parse time without touching
# data, and recovery is re-recording the version row (covered by the
# loud-failure checks below).
reapply_bad=""
for v in $(q "SELECT version FROM schema_migrations ORDER BY version;"); do
    case "$v" in 0007_*|0011_*|0015_*|0019_*|9999_*) continue;; esac
    q "DELETE FROM schema_migrations WHERE version='$v';"
    if out="$(./database/migrate.sh --only "$v" 2>&1)" && [ "$(q "SELECT COUNT(*) FROM schema_migrations WHERE version='$v';")" = "1" ]; then
        :
    else
        reapply_bad="${reapply_bad}${v} "
    fi
    q "INSERT IGNORE INTO schema_migrations (version) VALUES ('$v');"
done
./database/migrate.sh >/dev/null 2>&1 || true
check "every recorded migration re-applies" "" "$reapply_bad"

# --- documented exceptions fail loudly without corrupting -------------------
# 0011 narrows an ENUM (re-applying it on current data must fail instead of
# silently downgrading the column); 0015 and 0019 rewrite the primary key of
# an AUTO_INCREMENT table in one atomic statement (re-apply fails at parse
# time without touching data). Recovery is re-recording the version row.
q "INSERT INTO verification_logs (email, code, purpose, expires_at) VALUES ('zz_sent@test.com', '000000', 'MFA_RECOVERY', NOW() + INTERVAL 1 HOUR);"
q "DELETE FROM schema_migrations WHERE version='0011_password_reset_purpose';"
if ./database/migrate.sh --only 0011_password_reset_purpose >/dev/null 2>&1; then got11="applied"; else got11="failed"; fi
check "superseded re-apply fails loudly" "failed" "$got11"
check "failed re-apply changes nothing" "1" "$(q "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='$DB_NAME' AND table_name='verification_logs' AND column_name='purpose' AND column_type LIKE '%MFA_RECOVERY%';")"
q "DELETE FROM verification_logs WHERE email='zz_sent@test.com';"
q "INSERT IGNORE INTO schema_migrations (version) VALUES ('0011_password_reset_purpose');"
check "version re-recorded after loud failure" "1" "$(q "SELECT COUNT(*) FROM schema_migrations WHERE version='0011_password_reset_purpose';")"
q "DELETE FROM schema_migrations WHERE version='0015_pending_key_scoped';"
if ./database/migrate.sh --only 0015_pending_key_scoped >/dev/null 2>&1; then got15="applied"; else got15="failed"; fi
check "scoped-key re-apply fails loudly" "failed" "$got15"
check "failed re-apply keeps the primary key" "id" "$(q "SELECT GROUP_CONCAT(column_name ORDER BY seq_in_index) FROM information_schema.statistics WHERE table_schema='$DB_NAME' AND table_name='pending_transactions' AND index_name='PRIMARY';")"
q "INSERT IGNORE INTO schema_migrations (version) VALUES ('0015_pending_key_scoped');"
check "version re-recorded after loud failure" "1" "$(q "SELECT COUNT(*) FROM schema_migrations WHERE version='0015_pending_key_scoped';")"
q "DELETE FROM schema_migrations WHERE version='0019_pending_id';"
if ./database/migrate.sh --only 0019_pending_id >/dev/null 2>&1; then got19="applied"; else got19="failed"; fi
check "atomic rewrite re-apply fails loudly" "failed" "$got19"
check "failed re-apply keeps the primary key" "id" "$(q "SELECT GROUP_CONCAT(column_name ORDER BY seq_in_index) FROM information_schema.statistics WHERE table_schema='$DB_NAME' AND table_name='pending_transactions' AND index_name='PRIMARY';")"
q "INSERT IGNORE INTO schema_migrations (version) VALUES ('0019_pending_id');"
check "version re-recorded after loud failure" "1" "$(q "SELECT COUNT(*) FROM schema_migrations WHERE version='0019_pending_id';")"
check "users.balance/verification_code dropped" "0" "$(q "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='$DB_NAME' AND table_name='users' AND column_name IN ('balance','verification_code');")"
check "exchange_rates table present (FX)" "1" "$(q "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME' AND table_name='exchange_rates';")"
check "FX pair lookup index present" "1" "$(q "SELECT COUNT(DISTINCT index_name) FROM information_schema.statistics WHERE table_schema='$DB_NAME' AND table_name='exchange_rates' AND index_name='idx_exchange_lookup';")"

# --- migration baseline (fresh installs start from schema.sql) ------------
base_list="$(grep -oE "'00[0-9]{2}_[a-z0-9_]+'" database/schema.sql | tr -d "'" | sort -u)"
file_list="$(for f in database/migrations/*.sql; do basename "$f" .sql; done | sort -u)"
check "baseline lists every migration file" "$file_list" "$base_list"
orphans="$(q "SELECT version FROM schema_migrations;" | sort -u | comm -23 - <(echo "$file_list"))"
check "no orphan migration records" "" "$orphans"
echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
