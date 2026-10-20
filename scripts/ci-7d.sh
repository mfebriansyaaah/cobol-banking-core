#!/bin/bash
# Fast gate for the 7-day volume sprint. It is not the full merge gate.
set -e
cd "$(dirname "$0")/.."

./build.sh > /tmp/cobol-7d-build.log 2>&1
./tests/warning_check.sh /tmp/cobol-7d-build.log
./tests/static_checks.sh
for suite in tests/lab/test_ref_*.sh; do
    [ -x "$suite" ] || chmod +x "$suite"
    "$suite"
done
echo "7D GATE GREEN"
