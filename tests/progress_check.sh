#!/bin/bash
# Progress check: every curated COBOL module must be documented in STATUS.md,
# and every traceability row claiming 'implemented' must carry test evidence.
# Usage: ./tests/progress_check.sh
set -e
cd "$(dirname "$0")/.."

fail=0

# 1) Every curated module file must appear in STATUS.md.
for f in cobol/src/*_core.cob; do
    [ -f "$f" ] || continue
    case "$f" in *generated*) continue ;; esac
    base=$(basename "$f")
    if ! grep -q "$base" docs/STATUS.md; then
        echo "progress: module '$base' is not documented in docs/STATUS.md"
        fail=1
    fi
done

# 2) Every 'implemented' traceability row must name test evidence.
while IFS= read -r line; do
    case "$line" in
        '| '[A-Z]* )
            id=$(awk -F'|' '{gsub(/^ *| *$/, "", $2); print $2}' <<<"$line")
            [ "$id" = "Req ID" ] && continue
            status=$(awk -F'|' '{gsub(/^ *| *$/, "", $4); print $4}' <<<"$line")
            tests=$(awk -F'|' '{gsub(/^ *| *$/, "", $6); print $6}' <<<"$line")
            if [ "$status" = "implemented" ]; then
                case "$tests" in
                    *tests/*|*middleware/test*) ;;
                    *) echo "progress: $id claims implemented without test evidence"; fail=1 ;;
                esac
            fi
            ;;
    esac
done < docs/TRACEABILITY.md

# 3) Every backticked module path in STATUS.md must exist.
for p in $(grep -oE '`cobol/src/[A-Za-z0-9_./-]+\.cob`' docs/STATUS.md | tr -d '`' | sort -u); do
    [ -e "$p" ] || { echo "progress: STATUS references missing module: $p"; fail=1; }
done

if [ "$fail" -ne 0 ]; then
    echo "progress check FAILED"
    exit 1
fi
echo "progress check OK"