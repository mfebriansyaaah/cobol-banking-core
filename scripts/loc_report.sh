#!/bin/bash
# Line-of-code report for the volume sprint.
# Counts tracked source files only; docs, markdown, lockfiles, binaries and
# backups are excluded. Net lines exclude blank and comment-only lines.
#
# Usage:
#   ./scripts/loc_report.sh
#   ./scripts/loc_report.sh --check
#   ./scripts/loc_report.sh --since main
set -e
cd "$(dirname "$0")/.."

SINCE=""
CHECK=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --since) SINCE="${2:-}"; shift 2 ;;
        --check) CHECK=1; shift ;;
        *) echo "usage: $0 [--since <ref>] [--check]" >&2; exit 2 ;;
    esac
done

files="$(git ls-files | grep -vE '^(docs/|backups/|cobol/bin/|middleware/node_modules/|database/fixtures/)' | grep -vE '\.md$|package-lock\.json$' || true)"

count_ext() {
    ext="$1"
    list="$(printf '%s\n' "$files" | grep -E "\.${ext}$" || true)"
    if [ -z "$list" ]; then
        printf '0 0 0 0\n'
        return
    fi
    printf '%s\n' "$list" | tr '\n' '\0' | xargs -0 cat | awk -v e="$ext" '
        { raw++ }
        /^[[:space:]]*$/ { blank++; next }
        {
            line=$0
            sub(/^[[:space:]]+/, "", line)
            if (e=="cob" && (line ~ /^\*/ || line ~ /^\*>/)) { comment++; next }
            if (e=="sh" && line ~ /^#/) { comment++; next }
            if ((e=="js" || e=="mjs" || e=="c") && (line ~ /^\/\// || line ~ /^\/\*/ || line ~ /^\*/)) { comment++; next }
            if (e=="sql" && line ~ /^--/) { comment++; next }
            code++
        }
        END { printf "%d %d %d %d\n", raw+0, blank+0, comment+0, code+0 }
    '
}

total_code=0
cobol_code=0
printf '%-8s %6s %9s %8s %9s %9s %8s\n' "language" "files" "raw" "blank" "comment" "net" "share"
for ext in cob c h sql sh js mjs; do
    n="$(printf '%s\n' "$files" | grep -cE "\.${ext}$" || true)"
    [ "$n" = "0" ] && continue
    read -r raw blank comment code <<< "$(count_ext "$ext")"
    total_code=$((total_code + code))
    [ "$ext" = "cob" ] && cobol_code=$((cobol_code + code))
done

for ext in cob c h sql sh js mjs; do
    n="$(printf '%s\n' "$files" | grep -cE "\.${ext}$" || true)"
    [ "$n" = "0" ] && continue
    read -r raw blank comment code <<< "$(count_ext "$ext")"
    share=0
    [ "$total_code" -gt 0 ] && share=$((code * 1000 / total_code))
    case "$ext" in
        cob) label="COBOL" ;;
        c) label="C" ;;
        h) label="C header" ;;
        sql) label="SQL" ;;
        sh) label="Shell" ;;
        js) label="JS" ;;
        mjs) label="JS module" ;;
        *) label="$ext" ;;
    esac
    printf '%-8s %6d %9d %8d %9d %9d %7d.%d%%\n' "$label" "$n" "$raw" "$blank" "$comment" "$code" $((share / 10)) $((share % 10))
done
printf '%-8s %6d %9s %8s %9s %9d\n' "TOTAL" "$(printf '%s\n' "$files" | grep -c . || true)" "" "" "" "$total_code"

if [ -n "$SINCE" ]; then
    echo
    echo "Added lines since $SINCE:"
    git diff --numstat "$SINCE" -- . | awk '
        function ext(path,  n,a) { n=split(path,a,"."); return n>1 ? a[n] : "" }
        {
            e=ext($3)
            if (e=="md" || $3 ~ /package-lock\.json$/) next
            if (e=="cob") cob+=$1
            total+=$1
        }
        END {
            printf "  COBOL added: %d\n  total added: %d\n", cob+0, total+0
            if (total > 0) printf "  COBOL share of additions: %d.%d%%\n", (cob*1000/total)/10, (cob*1000/total)%10
        }
    '
fi

if [ "$CHECK" = "1" ]; then
    echo
    if [ "$total_code" -le 0 ]; then
        echo "FAIL: no code lines counted"
        exit 1
    fi
    pct=$((cobol_code * 1000 / total_code))
    if [ "$pct" -lt 500 ]; then
        echo "FAIL: COBOL share is $((pct / 10)).$((pct % 10))% (minimum 50%)"
        exit 1
    fi
    if [ "$pct" -lt 550 ]; then
        echo "WARN: COBOL share is $((pct / 10)).$((pct % 10))% (target 55%+)"
    else
        echo "OK: COBOL share is $((pct / 10)).$((pct % 10))%"
    fi
fi
