#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Fail if obvious hardcoded secrets appear in source.
if grep -RInE "password\s*=\s*['\"][^'\"]+['\"]" middleware/src cobol/src 2>/dev/null | grep -vi "cobol_pass\|root" ; then
  echo "FAIL: possible hardcoded secret"
  exit 1
fi
echo "SAST extra passed."
