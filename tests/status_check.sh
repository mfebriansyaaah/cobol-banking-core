#!/bin/bash
# Status check: the claims in docs/STATUS.md must match the code.
# Verifies that (a) every action/action name in STATUS.md exists in the router
# or owning module, (b) every test suite and doc referenced exists.
# Usage: ./tests/status_check.sh

STATUS="docs/STATUS.md"
[ -f "$STATUS" ] || { echo "MISSING: $STATUS"; exit 1; }

fail=0

# 1) Every backticked ALL_CAPS action name in STATUS.md must exist either in
#    the router or in a core module.
for name in $(grep -oE '`[A-Z][A-Z_]{2,}`' "$STATUS" | tr -d '`' | sort -u); do
    if ! grep -q "$name" cobol/src/main_logic.cob cobol/src/wallet_core.cob cobol/src/user_core.cob cobol/src/auth_core.cob cobol/src/sql_bridge.c; then
        echo "STATUS claims action '$name' not found in any COBOL module"
        fail=1
    fi
done

# 2) Every referenced suite/doc file must exist.
for p in $(grep -oE '`(tests/[A-Za-z0-9_./-]+\.sh|SPEC-[A-Za-z-]+\.md|docs/[A-Za-z0-9_./-]+\.(md|sh)|database/[A-Za-z0-9_./-]+\.(sql|sh)|middleware/[A-Za-z0-9_./-]+\.(js|json))`' "$STATUS" | tr -d '`' | sort -u); do
    [ -e "$p" ] || { echo "STATUS references missing path: $p"; fail=1; }
done

# 3) The router and the starters must exist for the verify commands to work.
[ -f cobol/src/main_logic.cob ] || { echo "router missing"; fail=1; }

# 4) The headline assertion counts in STATUS.md must equal the baseline
#    manifest (shell total = every non-gateway entry, gateway total = the
#    gateway entry, full total = their sum), so the documented numbers cannot
#    drift from what CI actually runs.
BASE="tests/baseline_counts.txt"
if [ -f "$BASE" ]; then
    base_shell=$(awk '$1 !~ /^#/ && $1 != "gateway" {s+=$2} END {print s+0}' "$BASE")
    base_gw=$(awk '$1 == "gateway" {print $2}' "$BASE")
    base_full=$((base_shell + base_gw))
    status_shell=$(grep -oE 'Shell suites total \*\*[0-9]+\*\*' "$STATUS" | grep -oE '[0-9]+' | head -1)
    status_gw=$(grep -oE 'gateway suite \*\*[0-9]+\*\*' "$STATUS" | grep -oE '[0-9]+' | head -1)
    status_full=$(grep -oE '\*\*[0-9]+ assertions\*\*' "$STATUS" | grep -oE '[0-9]+' | head -1)
    [ "$status_shell" = "$base_shell" ] || { echo "STATUS shell total $status_shell != baseline $base_shell"; fail=1; }
    [ "$status_gw" = "$base_gw" ] || { echo "STATUS gateway total $status_gw != baseline $base_gw"; fail=1; }
    [ "$status_full" = "$base_full" ] || { echo "STATUS full total $status_full != baseline $base_full"; fail=1; }
else
    echo "baseline manifest missing: $BASE"
    fail=1
fi

[ "$fail" -eq 0 ] || { echo "status check FAILED"; exit 1; }
echo "status check OK"
