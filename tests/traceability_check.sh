#!/bin/bash
# Traceability check: docs/TRACEABILITY.md must map every P0/P1 requirement
# (plus the Gate 0 prerequisites) to a status, control, test/evidence,
# owner, and gate — with blockers explicit instead of silently unmapped.
# Requirements without a named owner stay UNASSIGNED (Gate 0); nothing here
# may read as a compliance claim. Usage: ./tests/traceability_check.sh

MATRIX="docs/TRACEABILITY.md"
[ -f "$MATRIX" ] || { echo "MISSING: $MATRIX"; exit 1; }

fail=0

# 1) Every requirement ID must appear exactly once as a table row.
EXPECTED="G0-ENTITY G0-SIGNOFF G0-MATRIX G0-PRODDATA G0-REASSESS A-P0-CDD A-P0-ACCESS A-P1-LIFECYCLE A-P1-RECOVERY B-P0-DOUBLE B-P0-BALANCE B-P0-PRECISION B-P1-LIFECYCLE B-P1-IDEM B-P1-RECON C-P0-RISK C-P0-LIMITS C-P1-FRAUDOPS D-P0-AUDIT D-P1-RECORDS D-P1-REPORTS E-P1-NOTIFY E-P1-DISPUTES F-P0-RESIL F-P0-SECOPS F-P1-DATA F-P1-CHANGE"
for id in $EXPECTED; do
    n=$(grep -cE "^\| $id \|" "$MATRIX")
    [ "$n" = "1" ] || { echo "traceability: requirement '$id' appears $n times (want exactly 1)"; fail=1; }
done

# 2) Row shape and vocabulary, enforced over the matrix body rows.
while IFS= read -r line; do
    case "$line" in
        '| '[A-Z]* )
            id=$(awk -F'|' '{gsub(/^ *| *$/, "", $2); print $2}' <<<"$line")
            # Skip the header row; validate only requirement rows.
            [ "$id" = "Req ID" ] && continue
            cells=$(awk -F'|' '{print NF}' <<<"$line")
            [ "$cells" = "10" ] || { echo "traceability: malformed row (want 8 cells): $line"; fail=1; continue; }
            status=$(awk -F'|' '{gsub(/^ *| *$/, "", $4); print $4}' <<<"$line")
            tests=$(awk -F'|' '{gsub(/^ *| *$/, "", $6); print $6}' <<<"$line")
            owner=$(awk -F'|' '{gsub(/^ *| *$/, "", $7); print $7}' <<<"$line")
            retention=$(awk -F'|' '{gsub(/^ *| *$/, "", $8); print $8}' <<<"$line")
            gate=$(awk -F'|' '{gsub(/^ *| *$/, "", $9); print $9}' <<<"$line")
            case "$status" in
                implemented|partial|missing) ;;
                *) echo "traceability: $id has unknown status '$status'"; fail=1 ;;
            esac
            [ -n "$owner" ] || { echo "traceability: $id has no owner (use UNASSIGNED until Gate 0 names one)"; fail=1; }
            [ -n "$retention" ] || { echo "traceability: $id has no retention/approval record"; fail=1; }
            [[ "$gate" =~ ^Gate\ [0-9](\ (BLOCKED|open))?$ ]] || { echo "traceability: $id has bad gate '$gate'"; fail=1; }
            if [ "$status" = "implemented" ]; then
                case "$tests" in
                    *tests/*|*middleware/test*) ;;
                    *) echo "traceability: $id claims implemented without test evidence"; fail=1 ;;
                esac
            fi
            if [ "$status" = "missing" ]; then
                case "$tests" in
                    *Blocked*) ;;
                    *) echo "traceability: $id is missing but names no blocker"; fail=1 ;;
                esac
            fi
            ;;
    esac
done < "$MATRIX"

# 3) Every backticked file path in the matrix must exist (mirrors docs_check
# for this file; future work stays in plain words, never backticks).
for p in $(grep -oE '`[A-Za-z0-9_./-]+\.(cob|c|sh|sql|bat|js|json|md)`' "$MATRIX" | tr -d '`' | sort -u); do
    case "$p" in
        */*) [ -e "$p" ] || { echo "traceability references missing path: $p"; fail=1; } ;;
    esac
done

[ "$fail" -eq 0 ] || { echo "traceability check FAILED"; exit 1; }
echo "traceability check OK"
