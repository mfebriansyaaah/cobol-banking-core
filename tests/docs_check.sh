#!/bin/bash
# Docs integrity check: every repo path referenced from AGENTS.md /
# CODING_STANDARDS.md / SPEC-*.md / docs/adr/*.md must actually exist.
# Guards against docs drifting from code and ADRs.
# Paths described as future/missing must be written WITHOUT backticks.
# Usage: ./tests/docs_check.sh

DOCS="AGENTS.md CODING_STANDARDS.md SPEC-auth-identity.md SPEC-user-profile.md SPEC-wallet-core.md SPEC-api-gateway.md docs/adr/0001-invocation-model.md docs/adr/0002-auth-db-stack.md"

fail=0
for doc in $DOCS; do
    [ -f "$doc" ] || { echo "MISSING DOC: $doc"; fail=1; continue; }

    paths=$(grep -oE '`[A-Za-z0-9_./-]+\.(cob|c|sh|sql|bat|js|json|md)`' "$doc" | tr -d '`' | sort -u)
    for p in $paths; do
        case "$p" in
            */*) [ -e "$p" ] || { echo "DANGLING PATH in $doc: $p"; fail=1; } ;;
        esac
    done
done

[ "$fail" -eq 0 ] || { echo "docs check FAILED"; exit 1; }
echo "docs check OK"
