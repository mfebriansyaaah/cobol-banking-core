#!/usr/bin/env bash
# Shell lint entry point, for local use and CI (P1-6).
# - shellcheck -x over every repo shell file plus build.sh: must be clean.
#   Real bugs live here (unquoted expansions, failing cds, A && B || C).
# - shfmt -i 4 --check over the toolchain allowlist below. Historical domain
#   suites (tests/db/*, tests/*.sh, ...) predate formatting and reformatting
#   500+ files is churn without safety value, so they are grandfathered;
#   every NEW toolchain file must be added here already formatted.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1

need() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "FAIL: $1 not found ($2)" >&2
        exit 2
    }
}
need shellcheck "apt install shellcheck or https://github.com/koalaman/shellcheck/releases"
need shfmt "apt install shfmt or https://github.com/mvdan/sh/releases"

echo "=== shellcheck (all repo shell files + build.sh) ==="
# Chunked: one shellcheck process over ~600 files is an order of magnitude
# slower than independent chunks (no cross-file analysis is lost: -x only
# follows sourced files, which stay inside each chunk's reach).
mapfile -t files < <(find tests scripts database -name '*.sh' | sort)
printf '%s\0' "${files[@]}" build.sh | xargs -0 -P "$(nproc)" -n 50 shellcheck -x
echo "shellcheck clean"

echo "=== shfmt (toolchain allowlist, -i 4) ==="
ALLOWLIST=(
    database/grants.sh
    scripts/ci/health_check.sh
    scripts/ci/lint.sh
    scripts/normalize_schema_dump.sh
    tests/lib/assert.sh
    tests/scripts/run.sh
    tests/scripts/test_db_guard.sh
)
unformatted="$(shfmt -i 4 -l "${ALLOWLIST[@]}" || true)"
if [ -n "$unformatted" ]; then
    echo "FAIL: files need shfmt -i 4:" >&2
    echo "$unformatted" >&2
    exit 1
fi
echo "shfmt clean (${#ALLOWLIST[@]} files)"
