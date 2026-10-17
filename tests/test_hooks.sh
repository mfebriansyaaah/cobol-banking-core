#!/bin/bash
# Git-hook hygiene suite: the installed commit-msg hook must match the
# tracked one (drift fails loudly), tampering is detected, and reinstalling
# restores the match. A trap restores the installed hook no matter how the
# suite exits, so a failure here can never leave the repo unguarded.
# Usage: ./tests/test_hooks.sh

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected [$expected] got [$actual])"; failed=$((failed+1))
    fi
}

echo "======================================================================"
echo "  GIT HOOK HYGIENE SUITE"
echo "======================================================================"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
HOOK=".git/hooks/commit-msg"
BACKUP="$(mktemp)"
cp "$HOOK" "$BACKUP"
trap 'cp "$BACKUP" "$HOOK"; chmod +x "$HOOK"; rm -f "$BACKUP"' EXIT

check "installed hooks match tracked" "0" "$(./scripts/install-hooks.sh --check >/dev/null 2>&1; echo $?)"

echo "# tampered" >> "$HOOK"
./scripts/install-hooks.sh --check >/dev/null 2>&1
check "tampered hook is detected" "1" "$?"

./scripts/install-hooks.sh >/dev/null 2>&1
check "reinstall restores the match" "0" "$(./scripts/install-hooks.sh --check >/dev/null 2>&1; echo $?)"
check "reinstalled hook identical" "" "$(diff hooks/commit-msg "$HOOK" | head -1)"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
