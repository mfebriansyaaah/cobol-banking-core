#!/bin/bash
# Docs integrity check: every tracked Markdown document is scanned for
# backticked repository paths, and each path must exist either from the repo
# root or relative to the document. Discover documents from Git so newly added
# runbooks/ADRs cannot silently escape this check.
# Paths described as future/missing must be written WITHOUT backticks.
# Usage: ./tests/docs_check.sh

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
DOCS="$(git ls-files '*.md')"

fail=0
for doc in $DOCS; do
    [ -f "$doc" ] || { echo "MISSING DOC: $doc"; fail=1; continue; }

    paths=$(grep -oE '`[A-Za-z0-9_./-]+\.(cob|c|sh|sql|bat|js|json|md)`' "$doc" | tr -d '`' | sort -u)
    for p in $paths; do
        case "$p" in
            */*)
                # Root-anchored repo paths and doc-relative paths are both
                # used; resolve exactly as a Markdown reader would.
                if [ ! -e "$p" ] && [ ! -e "$(dirname "$doc")/$p" ]; then
                    echo "DANGLING PATH in $doc: $p"
                    fail=1
                fi
                ;;
        esac
    done
done

[ "$fail" -eq 0 ] || { echo "docs check FAILED"; exit 1; }
echo "docs check OK"
