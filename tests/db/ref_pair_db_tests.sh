#!/usr/bin/env bash
# Reference-data shell coverage: ref_engine (RFE_*) + ref_ext (RX_*) pairs.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
require_db

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

db_seed
A="admin@test.com"
T="RFE-SHELL"
db_exec "DELETE FROM ref_value_version WHERE ref_value_id IN (SELECT id FROM ref_value WHERE type_code='${T}');"
db_exec "DELETE FROM ref_value WHERE type_code='${T}';"
db_exec "DELETE FROM ref_type WHERE type_code='${T}';"

# Engine types + values lifecycle.
assert_match "RFE_TYPE_CREATE ok" "$(run_cobol "RFE_TYPE_CREATE|${T}|Shell Type|A test type|||${A}")" "SUCCESS\|"
assert_match "RFE_TYPE_LIST ok" "$(run_cobol "RFE_TYPE_LIST|500|0||||${A}")" "SUCCESS\|"
assert_match "RFE_TYPE_LIST carries fixture" "$(run_cobol "RFE_TYPE_LIST|500|0||||${A}")" "${T}"
assert_match "RFE_VALUE_CREATE ok" "$(run_cobol "RFE_VALUE_CREATE|${T}|SH1|Shell One|k=v||${A}")" "SUCCESS\|"
assert_match "RFE_VALUE_GET ok" "$(run_cobol "RFE_VALUE_GET|${T}|SH1||||${A}")" "SUCCESS\|"
assert_match "RFE_VALUE_LIST ok" "$(run_cobol "RFE_VALUE_LIST|${T}|50|0|||${A}")" "SUCCESS\|"
assert_match "RFE_VALUE_HIST ok" "$(run_cobol "RFE_VALUE_HIST|${T}|SH1||||${A}")" "SUCCESS\|"
assert_match "RFE_VALUE_APPROVE ok" "$(run_cobol "RFE_VALUE_APPROVE|${T}|SH1|1|||${A}")" "SUCCESS\|"
assert_match "RX_VALUE_GET_ASOF ok" "$(run_cobol "RX_VALUE_GET_ASOF|${T}|SH1|$(date +%F)|||${A}")" "SUCCESS\|RX_ASOF"
assert_match "RFE_VALUE_RETIRE ok" "$(run_cobol "RFE_VALUE_RETIRE|${T}|SH1|obsolete|||${A}")" "SUCCESS\|"
assert_match "value retired" "$(db_query "SELECT status FROM ref_value_version WHERE ref_value_id=(SELECT id FROM ref_value WHERE type_code='${T}' AND code='SH1') ORDER BY version_no DESC LIMIT 1;")" "^RETIRED$"

# Ext pair on seeded country values (no fixture needed).
assert_match "RX_TRANSLATION_SET ok" "$(run_cobol "RX_TRANSLATION_SET|country|ID|en|Indonesia||${A}")" "SUCCESS\|"
assert_match "RX_TRANSLATION_LIST ok" "$(run_cobol "RX_TRANSLATION_LIST|country|ID|50|0||${A}")" "SUCCESS\|"
assert_match "translation listed" "$(run_cobol "RX_TRANSLATION_LIST|country|ID|50|0||${A}")" "en:Indonesia"
assert_match "RX_HIERARCHY_ADD ok" "$(run_cobol "RX_HIERARCHY_ADD|country|ID|US|||${A}")" "SUCCESS\|"
assert_match "RX_HIERARCHY_LIST ok" "$(run_cobol "RX_HIERARCHY_LIST|country|ID|50|0||${A}")" "SUCCESS\|"
assert_match "RX_VALUE_CLONE ok" "$(run_cobol "RX_VALUE_CLONE|country|ID|IDX|Indonesia copy||${A}")" "SUCCESS\|"
assert_match "clone present" "$(db_query "SELECT COUNT(*) FROM ref_value WHERE type_code='country' AND code='IDX';")" "^1$"
assert_match "RX_EXPORT ok" "$(run_cobol "RX_EXPORT|country|CSV||||${A}")" "SUCCESS\|"
assert_match "RX_HIERARCHY_REMOVE ok" "$(run_cobol "RX_HIERARCHY_REMOVE|country|ID|US|||${A}")" "SUCCESS\|"
assert_match "non-admin refused" "$(run_cobol "RFE_TYPE_LIST|50|0||||sender@test.com")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM ref_translation WHERE ref_value_id IN (SELECT id FROM ref_value WHERE type_code='country' AND code IN ('IDX'));"
db_exec "DELETE FROM ref_hierarchy WHERE parent_value_id IN (SELECT id FROM ref_value WHERE type_code='country' AND code='IDX') OR child_value_id IN (SELECT id FROM ref_value WHERE type_code='country' AND code='IDX');"
db_exec "DELETE FROM ref_value WHERE type_code='country' AND code='IDX';"
db_exec "DELETE FROM ref_translation WHERE ref_value_id IN (SELECT id FROM ref_value WHERE type_code='country' AND code='ID') AND locale='en';"
db_exec "DELETE FROM ref_hierarchy h USING ref_hierarchy h JOIN ref_value p ON p.id=h.parent_value_id JOIN ref_value c ON c.id=h.child_value_id WHERE p.type_code='country' AND p.code='ID' AND c.code='US';"
db_exec "DELETE FROM ref_value_version WHERE ref_value_id IN (SELECT id FROM ref_value WHERE type_code='${T}');"
db_exec "DELETE FROM ref_value WHERE type_code='${T}';"
db_exec "DELETE FROM ref_type WHERE type_code='${T}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
