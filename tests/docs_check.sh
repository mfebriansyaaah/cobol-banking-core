#!/bin/bash
# Docs integrity check: every repo path referenced from SPEC-*.md / AGENTS.md /
# CODING_STANDARDS.md must actually exist. Guards against specs drifting from code.
# Paths described as future/missing must be written WITHOUT backticks.
# Usage: ./tests/docs_check.sh

DOCS="AGENTS.md CODING_STANDARDS.md SPEC-auth-identity.md SPEC-user-profile.md SPEC-wallet-core.md SPEC-api-gateway.md"

fail=0
for doc in $DOCS; do
    [ -f "$doc" ] || { echo "MISSING DOC: $doc"; fail=1; continue; }

    paths=$(grep -oE '`[A-Za-z0-9_./-]+\.(cob|c|sh|sql|bat)`' "$doc" | tr -d '`' | sort -u)
    for p in $paths; do
        case "$p" in
            */*) [ -e "$p" ] || { echo "DANGLING PATH in $doc: $p"; fail=1; } ;;
        esac
    done
done

[ "$fail" -eq 0 ] || { echo "docs check FAILED"; exit 1; }
echo "docs check OK"
