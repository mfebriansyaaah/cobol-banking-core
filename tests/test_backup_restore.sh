#!/bin/bash
# Backup/restore suite: a backup round-trips through restore.sh and the
# restored database verifies against the manifest (row counts, checksums,
# migrations, bridge smoke). A canary row written after the backup must be
# gone afterwards, proving the restore actually rewound the data.
# Usage: ./tests/test_backup_restore.sh
#
# This suite restores the database from the backup it just took. The window
# is seconds and CI runs suites sequentially, so no committed row is at
# risk; a verification failure fails loudly instead of hiding corruption.

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

BAKDIR="./backups/.ci-verify-$$"
CANARY="bakcanary_$$"

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected [$expected] got [$actual])"; failed=$((failed+1))
    fi
}

echo "======================================================================"
echo "  BACKUP/RESTORE SUITE"
echo "======================================================================"

if ./scripts/backup.sh "$BAKDIR" > /tmp/opencode/bak_out.txt 2>&1; then
    check "backup completes" "0" "0"
else
    check "backup completes" "0" "1"
fi
SQL="$(ls "$BAKDIR"/*.sql 2>/dev/null | head -1)"
MANIFEST="${SQL%.sql}.manifest"
check "dump file exists" "1" "$([ -f "$SQL" ] && echo 1 || echo 0)"
check "manifest exists" "1" "$([ -f "$MANIFEST" ] && echo 1 || echo 0)"
check "dump is owner-only" "600" "$(stat -c %a "$SQL" 2>/dev/null)"
check "manifest is owner-only" "600" "$(stat -c %a "$MANIFEST" 2>/dev/null)"
check "manifest records git rev" "1" "$(grep -c '^git_rev: [0-9a-f]*$' "$MANIFEST")"
check "manifest covers all 28 tables" "28" "$(grep -c '^table ' "$MANIFEST")"
check "dump carries latest schema" "1" "$(grep -c 'CREATE TABLE .*dispute_cases' "$SQL")"
check "dump carries triggers" "1" "$(grep -c 'trg_ledger_no_update' "$SQL")"

mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e \
    "INSERT INTO dispute_cases (user_id, subject, detail) VALUES (1,'$CANARY','canary');" 2>/dev/null
check "canary written" "1" "$(mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "SELECT COUNT(*) FROM dispute_cases WHERE subject='$CANARY';" 2>/dev/null)"

if ./scripts/restore.sh "$SQL" > /tmp/opencode/restore_out.txt 2>&1; then
    check "restore verifies" "0" "0"
    check "restore says verified" "1" "$(grep -c 'verified$' /tmp/opencode/restore_out.txt)"
else
    check "restore verifies" "0" "1"
    check "restore says verified" "1" "0"
fi
check "canary is gone after restore" "0" "$(mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "SELECT COUNT(*) FROM dispute_cases WHERE subject='$CANARY';" 2>/dev/null)"
check "migrations still applied" "all migrations applied" "$(./database/migrate.sh --check 2>&1 | tail -1)"
printf 'RECONCILE|admin@test.com\n' > input.txt
check "bridge works after restore" "0" "$(./cobol/bin/main_logic >/dev/null 2>&1; echo $?)"

rm -rf "$BAKDIR"

echo "======================================================================"
echo "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
