#!/bin/bash
# Auto-sync docs/STATUS.md module sections: for every curated COBOL module that
# is not yet documented, append a section listing its actions (parsed from the
# module's EVALUATE dispatch). Idempotent: modules already referenced are skipped.
# Usage: ./scripts/sync_status_modules.sh
set -e
cd "$(dirname "$0")/.."

STATUS="docs/STATUS.md"
changed=0
for f in cobol/src/*_core.cob; do
    [ -f "$f" ] || continue
    case "$f" in *generated*) continue ;; esac
    base=$(basename "$f")
    if grep -q "$base" "$STATUS"; then
        continue
    fi
    # actions parsed from the module's EVALUATE WHEN clauses
    actions=$(grep 'LS-CMD-ACTION' "$f" | grep -oE '"[A-Z][A-Z_]+"' | tr -d '"' | sort -u)
    [ -n "$actions" ] || continue
    {
        echo ""
        echo "## $base"
        echo ""
        echo "| Module | Action | Behavior |"
        echo "|---|---|---|"
        for a in $actions; do
            echo "| \`cobol/src/$base\` | \`$a\` | (auto-documented; refine description) |"
        done
    } >> "$STATUS"
    changed=1
    echo "synced: $base"
done

if [ "$changed" = "1" ]; then
    echo "STATUS.md updated with missing module sections."
else
    echo "STATUS.md already documents all curated modules."
fi