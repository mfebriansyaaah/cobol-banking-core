#!/usr/bin/env bash
# Zero-to-green developer bootstrap (P1-7): check dependencies, start the
# Docker Compose test database, provision it, build the core, and run the
# fast suite. Every step is idempotent; re-running is safe.
# Usage: scripts/dev/bootstrap.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

missing=""
need() {
    if command -v "$1" >/dev/null 2>&1; then
        echo "have $1"
    else
        echo "MISSING $1 ($2)"
        missing="$missing $1"
    fi
}

echo "=== bootstrap: dependency check ==="
need docker "https://docs.docker.com/get-docker (or use the system package manager)"
need node "https://nodejs.org (need >= 20)"
need make "system package manager (build-essential)"
need gcc "system package manager (build-essential)"
need mysql "mariadb-client package (or mysql-client)"
need cobc "gnucobol package (apt gnucobol is enough to build and test; coverage needs 3.2, see scripts/ci/install_gnucobol.sh)"
if [ -n "$missing" ]; then
    echo "FAIL: missing dependencies:$missing" >&2
    exit 2
fi

echo "=== bootstrap: test database ==="
docker compose -f docker-compose.test.yml up -d
scripts/dev/setup-test-db.sh

echo "=== bootstrap: build ==="
./build.sh

echo "=== bootstrap: fast suite ==="
tests/run_all.sh fast

echo "=== BOOTSTRAP GREEN (next: make test-db, make test-full) ==="
