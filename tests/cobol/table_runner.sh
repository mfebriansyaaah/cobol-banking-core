#!/usr/bin/env bash
# Table-driven COBOL core tests. Reads *.cases files (name@@expected@@input).
# Usage: tests/cobol/table_runner.sh [case-file ...]
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# Some table cases need the seeded admin account. Seed when a database is
# reachable; the pure-validation cases still run without one.
if db_available; then
    db_seed
fi
# Start the persistent COBOL server once for all cases (db_seed above only
# runs when a database is reachable; pure-validation cases need it too).
# start_cobol_server is idempotent, so this is a no-op if db_seed started it.
if [ "${COBOL_TEST_SERVE:-1}" = "1" ]; then
    start_cobol_server 2>/dev/null || true
fi
T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

CASES_DIR="$ROOT/tests/cobol/cases"

files=()
if [ $# -gt 0 ]; then
    for a in "$@"; do
        if [ -d "$a" ]; then
            for f in "$a"/*.cases; do [ -f "$f" ] && files+=("$f"); done
        else
            files+=("$a")
        fi
    done
else
    for f in "$CASES_DIR"/*.cases; do [ -f "$f" ] && files+=("$f"); done
fi

if [ "${#files[@]}" -eq 0 ]; then
    echo "no case files found" >&2
    exit 2
fi

for cf in "${files[@]}"; do
    echo "# suite: $(basename "$cf")"
    while IFS= read -r line || [ -n "$line" ]; do
        # strip leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        case "$line" in ''|\#*) continue;; esac
        name="${line%%@@*}"
        rest="${line#*@@}"
        expected="${rest%%@@*}"
        input="${rest#*@@}"
        out="$(run_cobol "$input")"
        assert_match "$name" "$out" "$expected"
    done < "$cf"
done

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
