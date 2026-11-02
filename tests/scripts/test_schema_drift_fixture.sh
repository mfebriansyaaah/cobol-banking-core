#!/usr/bin/env bash
# Fixture test for scripts/normalize_schema_dump.sh (the drift gate's
# volatile-bit normalization). No database needed: a canned mysqldump excerpt
# goes through the normalizer and the output must equal the expectation
# exactly; normalizing twice must change nothing (idempotent).
# Usage: tests/scripts/test_schema_drift_fixture.sh (or via tests/scripts/run.sh)
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok - $1"; }
not_ok() { FAIL=$((FAIL + 1)); echo "not ok - $1"; }

IN="$(mktemp "${TMPDIR:-/tmp}/drift-fixture-in.XXXXXX.sql")"
EXPECTED="$(mktemp "${TMPDIR:-/tmp}/drift-fixture-exp.XXXXXX.sql")"
trap 'rm -f "$IN" "$EXPECTED"' EXIT

cat > "$IN" <<'EOF'
-- MariaDB dump 10.20-11.8.9-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: 127.0.0.1    Database: cobol_db_test_snapshot_4242
-- ------------------------------------------------------
CREATE TABLE `users` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `email` varchar(100) DEFAULT NULL
) ENGINE=InnoDB AUTO_INCREMENT=987 DEFAULT CHARSET=utf8mb4;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_user` AS SELECT `id` FROM `users` */;
--
-- Dumping routines for database 'cobol_db_test_snapshot_4242'
--
/*!50003 CREATE*/ /*!50020 DEFINER=`cobol_user`@`%`*/ /*!50003 TRIGGER `trg_x` BEFORE INSERT ON `t` FOR EACH ROW SET @a=1 */;
EOF

cat > "$EXPECTED" <<'EOF'
--
-- ------------------------------------------------------
CREATE TABLE `users` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `email` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013  SQL SECURITY DEFINER */
/*!50001 VIEW `v_user` AS SELECT `id` FROM `users` */;
--
-- Dumping routines for database 'SNAPSHOT_DB'
--
/*!50003 CREATE*/ /*!50020 */ /*!50003 TRIGGER `trg_x` BEFORE INSERT ON `t` FOR EACH ROW SET @a=1 */;
EOF

got="$(bash "$ROOT/scripts/normalize_schema_dump.sh" cobol_db_test_snapshot_4242 < "$IN")"
want="$(cat "$EXPECTED")"
if [ "$got" = "$want" ]; then
    ok "normalizer strips DEFINER, AUTO_INCREMENT counters, and the db name"
else
    not_ok "normalizer strips DEFINER, AUTO_INCREMENT counters, and the db name"
    diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -12
fi

# A 10.11-client dump of the same schema (banner, server build, SQL_NOTES
# session line, and pre-normalization connection charset) must converge to
# the identical normalized form as the 11.8-client dump above.
OLD_CLIENT="$(mktemp "${TMPDIR:-/tmp}/drift-fixture-old.XXXXXX.sql")"
trap 'rm -f "$IN" "$EXPECTED" "$OLD_CLIENT"' EXIT
cat > "$OLD_CLIENT" <<'EOF'
-- MariaDB dump 10.19  Distrib 10.11.14-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: 127.0.0.1    Database: cobol_db_test_snapshot_4242
-- ------------------------------------------------------
-- Server version	11.8.9-MariaDB-ubu2404

/*!40101 SET NAMES utf8mb4 */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
CREATE TABLE `users` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `email` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
EOF
old_norm="$(bash "$ROOT/scripts/normalize_schema_dump.sh" cobol_db_test_snapshot_4242 < "$OLD_CLIENT")"
# The old-client header block normalizes to nothing but the blank/comment
# lines both clients share; the table body is untouched.
if printf '%s' "$old_norm" | grep -qE "MariaDB dump|Server version|SQL_NOTES|NOTE_VERBOSITY|cobol_db_test_snapshot_4242"; then
    not_ok "old-client dump converges (client boilerplate remains)"
else
    ok "old-client dump converges (client boilerplate removed)"
fi
if printf '%s' "$old_norm" | grep -q "CREATE TABLE \`users\`"; then
    ok "old-client dump keeps schema content"
else
    not_ok "old-client dump keeps schema content"
fi

# A newer client splits trigger endings across two lines (END <newline>
# */;;) while older clients keep them on one line; both must converge.
# Backticks are literal here: the compared dump text contains trigger
# definitions with `t` in backticks (SC2016 does not apply).
# shellcheck disable=SC2016
SPLIT_END="$(printf '/*!50003 TRIGGER `t` FOR EACH ROW BEGIN\nSELECT 1;\nEND \n*/;;')"
# shellcheck disable=SC2016
if [ "$(printf '%s' "$SPLIT_END" | bash "$ROOT/scripts/normalize_schema_dump.sh")" = '/*!50003 TRIGGER `t` FOR EACH ROW BEGIN
SELECT 1;
END */;;' ]; then
    ok "split trigger endings join to the single-line form"
else
    not_ok "split trigger endings join to the single-line form"
fi

again="$(printf '%s' "$got" | bash "$ROOT/scripts/normalize_schema_dump.sh" cobol_db_test_snapshot_4242)"
if [ "$again" = "$got" ]; then
    ok "normalization is idempotent"
else
    not_ok "normalization is idempotent"
fi

plain="$(printf 'X cobol_db_test_snapshot_9 Y' | bash "$ROOT/scripts/normalize_schema_dump.sh")"
if [ "$plain" = "X cobol_db_test_snapshot_9 Y" ]; then
    ok "no db name given: other rules still apply, names untouched"
else
    not_ok "no db name given: other rules still apply, names untouched"
fi

echo "=== SCHEMA DRIFT FIXTURE: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
