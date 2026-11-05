#!/usr/bin/env bash
# Parity checklist for scripts/ci/premerge.sh --ci-parity (CI-005).
#
# Every CI lint/build gate must have a local equivalent in run_ci_parity.
# If CI gains a gate without a premerge equivalent, this test fails until
# premerge covers it (or documents the exclusion deliberately).
#
# No database, no build, no network: pure text assertions on the committed
# tree, so it runs in the offline harness (tests/scripts/run.sh).
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PREMERGE="$ROOT/scripts/ci/premerge.sh"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok - $1"; }
not_ok() { FAIL=$((FAIL + 1)); echo "not ok - $1"; }

check_present() { # $1 = description, $2 = fixed string in premerge.sh
    if grep -qF "$2" "$PREMERGE"; then
        ok "$1"
    else
        not_ok "$1 (missing '$2' in scripts/ci/premerge.sh)"
    fi
}

check_present "actionlint runs in --ci-parity" "actionlint"
check_present "shared YAML lint runs in --ci-parity" "yaml_lint.sh"
check_present "gate unit tests run in --ci-parity" "test:scripts"
check_present "SAST scan runs in --ci-parity" "sast.sh"
check_present "SAST extra scan runs in --ci-parity" "sast_extra.sh"
check_present "opt-in COBOL coverage exists" "PREMERGE_COBOL_COVERAGE"

if [ -x "$ROOT/scripts/ci/yaml_lint.sh" ]; then
    ok "scripts/ci/yaml_lint.sh exists and is executable"
    if grep -qF "scripts/ci/yaml_lint.sh" "$ROOT/.github/workflows/ci.yml"; then
        ok "ci.yml uses the shared YAML lint entrypoint"
    else
        not_ok "ci.yml uses the shared YAML lint entrypoint"
    fi
else
    not_ok "scripts/ci/yaml_lint.sh exists and is executable"
fi

echo "=== PREMERGE PARITY: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
