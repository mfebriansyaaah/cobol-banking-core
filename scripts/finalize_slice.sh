#!/bin/bash
# Finalize a slice before the full CI gate.
#
#   ./scripts/finalize_slice.sh          # update baselines and documented counts
#   ./scripts/finalize_slice.sh --check  # verify only; do not modify
#
# It updates:
#   - tests/non_generated_baseline.txt
#   - tests/curated_share_baseline.txt (only upward)
#   - README.md current-state table
#   - docs/DELIVERY_RULES.md baseline table and gap
#   - docs/STATUS.md headline suite/assertion counts and baseline line
#
# The developer still adds the new suite row/count to tests/baseline_counts.txt
# and docs/STATUS.md; this script synchronizes the derived totals.
set -euo pipefail
cd "$(dirname "$0")/.."

CHECK=0
if [ "${1:-}" = "--check" ]; then
    CHECK=1
elif [ "$#" -gt 0 ]; then
    echo "usage: $0 [--check]" >&2
    exit 2
fi

if [ "$CHECK" -eq 0 ]; then
    untracked="$(git ls-files --others --exclude-standard | grep -E '\.(cob|sql|sh|js|c|h)$' || true)"
    if [ -n "$untracked" ]; then
        echo "finalize: stage new code files first (git add), then re-run:" >&2
        printf '%s\n' "$untracked" | sed 's/^/  /' >&2
        exit 1
    fi
fi

report="$(./scripts/loc_report.sh --non-generated)"
quality="$(./scripts/loc_report.sh --quality)"

total="$(printf '%s\n' "$report" | awk '$1=="total" && $2=="net:" {print $3}')"
cobol="$(printf '%s\n' "$report" | awk '$1=="COBOL" && $2=="net:" {print $3}')"
cnet="$(printf '%s\n' "$report" | awk '$1=="C" && $2=="net:" {print $3}')"
sql="$(printf '%s\n' "$report" | awk '$1=="SQL" && $2=="net:" {print $3}')"
shell="$(printf '%s\n' "$report" | awk '$1=="Shell" && $2=="net:" {print $3}')"
js="$(printf '%s\n' "$report" | awk '$1=="JS" && $2=="net:" {print $3}')"
share="$(printf '%s\n' "$report" | awk '$1=="COBOL" && $2=="share:" {print $3}')"
curated="$(printf '%s\n' "$quality" | awk '$1=="curated" && $2=="net:" {print $3}')"
generated="$(printf '%s\n' "$quality" | awk '$1=="generated" && $2=="net:" {print $3}')"
curated_pct="$(printf '%s\n' "$quality" | awk '$1=="curated" && $2=="net:" {gsub(/[()%]/,"",$4); print $4}')"
cobol_total=$((curated + generated))
for v in total cobol cnet sql shell js share curated generated; do
    [ -n "${!v}" ] || { echo "finalize: could not parse $v from loc report" >&2; exit 1; }
done

gap=$((100000 - total))
[ "$gap" -lt 0 ] && gap=0
shell_total="$(awk '$1 !~ /^#/ && $1 != "gateway" {s+=$2} END {print s+0}' tests/baseline_counts.txt)"
gateway_total="$(awk '$1 == "gateway" {print $2}' tests/baseline_counts.txt)"
full_total=$((shell_total + gateway_total))
steps="$(grep -c '^echo "=== \[' ci.sh)"
today="$(date +%Y-%m-%d)"

if [ "$CHECK" -eq 1 ]; then
    ./scripts/loc_report.sh --non-generated --check
    ./tests/status_check.sh
    ./tests/docs_check.sh
    ./tests/traceability_check.sh
    echo "finalize check OK: total=$total cobol=$cobol share=$share gap=$gap suites=$shell_total+$gateway_total steps=$steps"
    exit 0
fi

python3 - "$total" "$cobol" "$cnet" "$sql" "$shell" "$js" "$share" "$gap" \
    "$curated_pct" "$cobol_total" "$shell_total" "$gateway_total" "$full_total" "$steps" "$today" <<'PY'
from pathlib import Path
import re, sys

(total, cobol, cnet, sql, shell, js, share, gap, curated_pct, cobol_total,
 shell_total, gateway_total, full_total, steps, today) = sys.argv[1:]

def n(v):
    return int(v)

def fmt(v):
    return f"{n(v):,}".replace(",", ".")

def pct(v):
    return f"{v}".replace(".", ",")

total_f, cobol_f, cnet_f, sql_f, shell_f, js_f, gap_f = map(fmt, (total, cobol, cnet, sql, shell, js, gap))
share_f = pct(share.replace("%", ""))
curated_f = pct(curated_pct)
shell_f2 = str(n(shell_total))
gateway_f2 = str(n(gateway_total))
full_f2 = str(n(full_total))

# Baseline file.
p = Path("tests/non_generated_baseline.txt")
s = p.read_text()
s = re.sub(r"(?m)^non_generated_net \d+$", f"non_generated_net {n(total)}", s)
s = re.sub(r"(?m)^non_generated_cobol_net \d+$", f"non_generated_cobol_net {n(cobol)}", s)
p.write_text(s)

# README current-state table.
p = Path("README.md")
s = p.read_text()
s = re.sub(r"\| Non-generated net \| \*\*[0-9.]+\*\* \|", f"| Non-generated net | **{total_f}** |", s)
s = re.sub(r"\| Curated COBOL net \| \*\*[0-9.]+\*\* \([0-9,]+%\) \|",
           f"| Curated COBOL net | **{cobol_f}** ({share_f}%) |", s)
s = re.sub(r"\| Total COBOL net \| \*\*[0-9.]+\*\* \|", f"| Total COBOL net | **{fmt(cobol_total)}** |", s)
s = re.sub(r"\| Full CI \| \*\*[0-9]+ steps / [0-9.]+ assertions\*\* \|",
           f"| Full CI | **{steps} steps / {full_f2} assertions** |", s)
s = re.sub(r"Measured \d{4}-\d{2}-\d{2}:", f"Measured {today}:", s)
s = re.sub(r"\| Non-generated gap to 100\.000 \| \*\*[0-9.]+\*\* \|",
           f"| Non-generated gap to 100.000 | **{gap_f}** |", s)
p.write_text(s)

# Delivery rules baseline table and gap.
p = Path("docs/DELIVERY_RULES.md")
s = p.read_text()
s = re.sub(r"\| Curated COBOL \| [0-9.]+ \|", f"| Curated COBOL | {cobol_f} |", s)
s = re.sub(r"\| C and header \| [0-9.]+ \|", f"| C and header | {cnet_f} |", s)
s = re.sub(r"\| SQL \| [0-9.]+ \|", f"| SQL | {sql_f} |", s)
s = re.sub(r"\| Shell \| [0-9.]+ \|", f"| Shell | {shell_f} |", s)
s = re.sub(r"\| JavaScript \| [0-9.]+ \|", f"| JavaScript | {js_f} |", s)
s = re.sub(r"\| \*\*Total non-generated\*\* \| \*\*[0-9.]+\*\* \|",
           f"| **Total non-generated** | **{total_f}** |", s)
s = re.sub(r"\| COBOL share \| [0-9,]+% \|", f"| COBOL share | {share_f}% |", s)
s = re.sub(r"\| Remaining gap \| \*\*[0-9.]+\*\* \|", f"| Remaining gap | **{gap_f}** |", s)
p.write_text(s)

# Status headline counts and baseline line.
p = Path("docs/STATUS.md")
s = p.read_text()
s = re.sub(r"Shell suites total \*\*[0-9.]+\*\*; with the gateway suite \*\*[0-9.]+\*\* the full run is\n\*\*[0-9.]+ assertions\*\*",
           f"Shell suites total **{shell_f2}**; with the gateway suite **{gateway_f2}** the full run is\n**{full_f2} assertions**", s)
s = re.sub(r"full `\./ci\.sh` \([0-9]+ steps\)", f"full `./ci.sh` ({steps} steps)", s)
s = re.sub(r"Non-generated net baseline: [0-9.]+;", f"Non-generated net baseline: {total_f};", s)
s = re.sub(r"as of \d{4}-\d{2}-\d{2}", f"as of {today}", s)
p.write_text(s)

# Curated-share ratchet, only upward.
p = Path("tests/curated_share_baseline.txt")
s = p.read_text()
m = re.search(r"(?m)^curated_share_per_mille (\d+)$", s)
current = int(round(float(str(curated_pct).replace(",", ".")) * 10))
if m and current > int(m.group(1)):
    s = re.sub(r"(?m)^curated_share_per_mille \d+$",
               f"curated_share_per_mille {current}", s)
    p.write_text(s)

print(f"finalize: total={total_f} cobol={cobol_f} share={share_f}% gap={gap_f} suites={shell_f2}+{gateway_f2} steps={steps}")
PY

./scripts/loc_report.sh --non-generated --check
./tests/status_check.sh
./tests/docs_check.sh
./tests/traceability_check.sh
echo "finalize OK: baseline and documented counts updated; run ./ci.sh next."
