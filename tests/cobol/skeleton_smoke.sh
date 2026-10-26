#!/usr/bin/env bash
# Smoke test: every skeleton module returns INVALID_ACTION instead of crashing.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
if ! command -v "$ROOT/cobol/bin/main_logic" >/dev/null 2>&1; then
  echo "SKIP: binary missing"
  exit 0
fi

# Prefix -> module mapping for skeleton (non-real) modules.
declare -A SKEL=(
  [BLP_]=billpay [FXH_]=fx_hedging [AML_]=aml_screening
  [SCL_]=sanctions_list [FRC_]=fraud_case [FAS_]=fixed_asset
  [CSC_]=cost_center [CNS_]=consolidation [IPM_]=incident_postmortem
  [CHA_]=change_approval [CFC_]=capacity_forecast [DLN_]=data_lineage
  [MDF_]=metric_definition [ASP_]=analytics_snapshot
)

fail=0
for prefix in "${!SKEL[@]}"; do
  action="${prefix}NOPE"
  printf '%s||||||admin@test.com\n' "$action" > "$ROOT/input.txt"
  DB_HOST="${DB_HOST:-localhost}" DB_PORT="${DB_PORT:-3306}" \
    DB_USER="${DB_USER:-cobol_user}" DB_PASS="${DB_PASS:-cobol_pass}" \
    DB_NAME="${DB_NAME:-cobol_db}" "$ROOT/cobol/bin/main_logic" >/dev/null 2>&1
  out="$(cat "$ROOT/output.txt" 2>/dev/null)"
  if [ "$out" != "ERROR|INVALID_ACTION" ]; then
    echo "FAIL: $action -> $out"
    fail=$((fail+1))
  else
    echo "OK: $action -> INVALID_ACTION"
  fi
done
if [ "$fail" -ne 0 ]; then exit 1; fi
echo "All skeleton smoke checks passed."
exit 0