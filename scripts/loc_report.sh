#!/bin/bash
# Line-of-code report for the production-grade transition.
# Counts tracked source files only; docs, markdown, lockfiles, binaries and
# backups are excluded. Net lines exclude blank and comment-only lines.
#
# Usage:
#   ./scripts/loc_report.sh
#   ./scripts/loc_report.sh --check
#   ./scripts/loc_report.sh --check-floor
#   ./scripts/loc_report.sh --quality
#   ./scripts/loc_report.sh --non-generated [--check]
#   ./scripts/loc_report.sh --since main
set -e
cd "$(dirname "$0")/.."

SINCE=""
CHECK=0
FLOOR=0
QUALITY=0
NONGEN=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --since) SINCE="${2:-}"; shift 2 ;;
        --check) CHECK=1; shift ;;
        --check-floor) CHECK=1; FLOOR=1; shift ;;
        --quality) QUALITY=1; shift ;;
        --non-generated) NONGEN=1; shift ;;
        *) echo "usage: $0 [--since <ref>] [--check] [--check-floor] [--quality]" >&2; exit 2 ;;
    esac
done

files="$(git ls-files | grep -vE '^(docs/|backups/|cobol/bin/|middleware/node_modules/|database/fixtures/)' | grep -vE '\.md$|package-lock\.json$' || true)"
cobol_files="$(printf '%s\n' "$files" | grep -E '\.cob$' || true)"

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

count_cobol_file() {
    awk '
        /^[[:space:]]*$/ { next }
        {
            line=$0
            sub(/^[[:space:]]+/, "", line)
            if (line ~ /^\*/ || line ~ /^\*>/) next
            code++
        }
        END { print code+0 }
    ' "$1"
}

count_net_file() {
    file="$1"
    ext="${file##*.}"
    awk -v e="$ext" '
        /^[[:space:]]*$/ { next }
        {
            line=$0
            sub(/^[[:space:]]+/, "", line)
            if (e=="cob" && (line ~ /^\*/ || line ~ /^\*>/)) next
            if (e=="sh" && line ~ /^#/) next
            if ((e=="js" || e=="mjs" || e=="c" || e=="h") && (line ~ /^\/\// || line ~ /^\/\*/ || line ~ /^\*/)) next
            if (e=="sql" && line ~ /^--/) next
            code++
        }
        END { print code+0 }
    ' "$file"
}

compute_non_generated() {
    read -r _ _ _ nong_cobol <<< "$(count_ext cob)"
    read -r _ _ _ nong_c <<< "$(count_ext c)"
    read -r _ _ _ nong_h <<< "$(count_ext h)"
    read -r _ _ _ nong_sql <<< "$(count_ext sql)"
    read -r _ _ _ nong_shell <<< "$(count_ext sh)"
    read -r _ _ _ nong_js <<< "$(count_ext js)"
    read -r _ _ _ nong_mjs <<< "$(count_ext mjs)"
    generated_cobol=0
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        case "$f" in
            cobol/src/generated/*) ;;
            *) continue ;;
        esac
        generated_cobol=$((generated_cobol + $(count_cobol_file "$f")))
    done <<< "$(printf '%s\n' "$files" | grep -E '\.cob$' || true)"
    nong_cobol=$((nong_cobol - generated_cobol))
    nong_c=$((nong_c + nong_h))
    nong_js=$((nong_js + nong_mjs))
    nong_total=$((nong_cobol + nong_c + nong_sql + nong_shell + nong_js))
    nong_files=$(printf '%s\n' "$files" | grep -E '\.(cob|c|h|sql|sh|js|mjs)$' | grep -v '^cobol/src/generated/' | wc -l)
    if [ "$nong_total" -gt 0 ]; then
        nong_cobol_per_mille=$((nong_cobol * 1000 / nong_total))
    else
        nong_cobol_per_mille=0
    fi
}

compute_quality() {
    curated_net=0
    generated_net=0
    curated_actions=0
    generated_actions=0
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        n="$(count_cobol_file "$f")"
        a="$(grep -cE '^[[:space:]]+WHEN LS-CMD-ACTION' "$f" 2>/dev/null || true)"
        case "$f" in
            cobol/src/generated/*)
                generated_net=$((generated_net + n))
                generated_actions=$((generated_actions + a))
                ;;
            *)
                curated_net=$((curated_net + n))
                curated_actions=$((curated_actions + a))
                ;;
        esac
    done <<< "$cobol_files"
    quality_total=$((curated_net + generated_net))
    if [ "$quality_total" -gt 0 ]; then
        curated_per_mille=$((curated_net * 1000 / quality_total))
        generated_per_mille=$((generated_net * 1000 / quality_total))
    else
        curated_per_mille=0
        generated_per_mille=0
    fi
}

if [ "$NONGEN" = "1" ]; then
    compute_non_generated
    echo "NON-GENERATED CODE (net; excludes @generated files)"
    echo "  COBOL net:   $nong_cobol"
    echo "  C net:       $nong_c"
    echo "  SQL net:     $nong_sql"
    echo "  Shell net:   $nong_shell"
    echo "  JS net:      $nong_js"
    echo "  total net:   $nong_total  ($nong_files files)"
    echo "  COBOL share: $((nong_cobol_per_mille / 10)).$((nong_cobol_per_mille % 10))%"
    baseline=""
    baseline_cobol=""
    if [ -f tests/non_generated_baseline.txt ]; then
        baseline="$(awk '$1 == "non_generated_net" {print $2}' tests/non_generated_baseline.txt)"
        baseline_cobol="$(awk '$1 == "non_generated_cobol_net" {print $2}' tests/non_generated_baseline.txt)"
    fi
    target=100000
    gap=$((target - nong_total))
    [ "$gap" -lt 0 ] && gap=0
    echo "  baseline:    ${baseline:-unset}"
    echo "  gap to 100000: $gap"
    if [ "$CHECK" = "1" ]; then
        if [ -z "$baseline" ]; then
            echo "FAIL: tests/non_generated_baseline.txt is missing or has no baseline"
            exit 1
        fi
        if [ "$nong_total" -lt "$baseline" ]; then
            echo "FAIL: non-generated net $nong_total is below baseline $baseline"
            exit 1
        fi
        if [ -n "$baseline_cobol" ] && [ "$nong_cobol" -lt "$baseline_cobol" ]; then
            echo "FAIL: non-generated COBOL $nong_cobol is below baseline $baseline_cobol"
            exit 1
        fi
        echo "OK: non-generated net $nong_total >= baseline $baseline"
    fi
    exit 0
fi

if [ "$QUALITY" = "1" ]; then
    compute_quality
    echo "COBOL quality"
    echo "  curated net:       $curated_net ($((curated_per_mille / 10)).$((curated_per_mille % 10))%)"
    echo "  generated net:     $generated_net ($((generated_per_mille / 10)).$((generated_per_mille % 10))%)"
    echo "  total net:         $quality_total"
    echo "  curated actions:   $curated_actions"
    echo "  generated actions: $generated_actions"
    if [ -f tests/curated_share_baseline.txt ]; then
        baseline="$(awk '$1 == "curated_share_per_mille" {print $2}' tests/curated_share_baseline.txt)"
        echo "  curated baseline:  ${baseline:-unset} per-mille"
    fi
    exit 0
fi

total_code=0
cobol_code=0
total_raw=0
cobol_raw=0
printf '%-8s %6s %9s %8s %9s %9s %8s\n' "language" "files" "raw" "blank" "comment" "net" "share"
for ext in cob c h sql sh js mjs; do
    n="$(printf '%s\n' "$files" | grep -cE "\.${ext}$" || true)"
    [ "$n" = "0" ] && continue
    read -r raw blank comment code <<< "$(count_ext "$ext")"
    total_code=$((total_code + code))
    total_raw=$((total_raw + raw))
    [ "$ext" = "cob" ] && cobol_code=$((cobol_code + code))
    [ "$ext" = "cob" ] && cobol_raw=$((cobol_raw + raw))
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
printf '%-8s %6d %9d %8s %9s %9d\n' "TOTAL" "$(printf '%s\n' "$files" | grep -c . || true)" "$total_raw" "" "" "$total_code"

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
    raw_pct=$((cobol_raw * 1000 / total_raw))
    echo "COBOL net share: $((pct / 10)).$((pct % 10))%"
    echo "COBOL raw share: $((raw_pct / 10)).$((raw_pct % 10))%"
    if [ "$pct" -lt 500 ] || [ "$raw_pct" -lt 500 ]; then
        echo "FAIL: COBOL share is below 50% (net $((pct / 10)).$((pct % 10))%, raw $((raw_pct / 10)).$((raw_pct % 10))%)"
        exit 1
    fi
    if [ "$pct" -lt 550 ] || [ "$raw_pct" -lt 550 ]; then
        echo "WARN: COBOL share is below the 55% target"
    else
        echo "OK: COBOL share meets the 55% target"
    fi
    if [ "$FLOOR" = "1" ]; then
        compute_quality
        if [ "$cobol_code" -lt 60000 ]; then
            echo "FAIL: COBOL net is $cobol_code (floor 60000)"
            exit 1
        fi
        echo "OK: COBOL net floor $cobol_code >= 60000"
        if [ -f tests/curated_share_baseline.txt ]; then
            baseline="$(awk '$1 == "curated_share_per_mille" {print $2}' tests/curated_share_baseline.txt)"
            [ -n "$baseline" ] || baseline=0
            if [ "$curated_per_mille" -lt $((baseline - 1)) ]; then
                echo "FAIL: curated COBOL share $curated_per_mille per-mille is below baseline $baseline"
                exit 1
            fi
            echo "OK: curated COBOL share $curated_per_mille per-mille >= baseline $baseline"
        fi
    fi
fi
