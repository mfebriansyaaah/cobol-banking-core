#!/usr/bin/env bash
# Static analysis (SAST) for SQL injection and auth bypass patterns.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

FAIL=0

echo "=== SAST: SQL injection patterns ==="
# Check for unparameterized SQL (string interpolation in SQL)
# COBOL uses SQL_PREPARE with ? placeholders; flag any SQL without ?
if grep -rn 'MOVE ".*SELECT.*' cobol/src/*.cob 2>/dev/null | grep -v '?' | grep -iv 'LAST_INSERT_ID\|COUNT(\*)\|dual_control\|access_reviews\|HOLD_EXPIRED\|recon_sla_policy' | grep -i 'WHERE' | head; then
  echo "WARNING: SQL with WHERE but no parameter placeholders"
  FAIL=1
fi

echo "=== SAST: Auth bypass patterns ==="
# Check middleware route files (excluding index.js) for missing auth guards
for f in middleware/src/routes/*.js; do
  [ "$(basename "$f")" = "index.js" ] && continue
  if ! grep -q "tokenIdentity" "$f"; then
    echo "WARNING: $f may lack auth guard"
    FAIL=1
  fi
done

echo "=== SAST: Hardcoded secrets ==="
if grep -rn "password.*=.*['\"]" middleware/src/ 2>/dev/null | grep -v "test\|example" | head; then
  echo "WARNING: Potential hardcoded secret"
  FAIL=1
fi

echo "=== SAST: eval/Function usage ==="
if grep -rn "eval(\|new Function(" middleware/src/ 2>/dev/null; then
  echo "WARNING: eval/Function usage detected"
  FAIL=1
fi

echo "=== SAST: manifest & route/dispatch contract ==="
if ! node scripts/check_manifest.mjs . >/tmp/sast_manifest.log 2>&1; then
  cat /tmp/sast_manifest.log
  echo "WARNING: manifest check failed"
  FAIL=1
fi
if ! node scripts/check_route_dispatch.mjs . >/tmp/sast_contract.log 2>&1; then
  cat /tmp/sast_contract.log
  echo "WARNING: route/dispatch contract check failed"
  FAIL=1
fi
if ! node scripts/check_action_coverage.mjs . >/tmp/sast_coverage.log 2>&1; then
  cat /tmp/sast_coverage.log
  echo "WARNING: action coverage check failed"
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
  echo "SAST found issues."
  exit 1
fi
echo "SAST scan passed."