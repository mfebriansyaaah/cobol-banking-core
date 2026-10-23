#!/bin/bash
# Print a human-readable progress dashboard from the tracked artifacts.
# Usage: ./scripts/progress_report.sh
set -e
cd "$(dirname "$0")/.."

echo "=== Module coverage ==="
curated=$(ls cobol/src/*_core.cob 2>/dev/null | grep -v generated | wc -l | tr -d ' ')
documented=$(grep -oE '`cobol/src/[A-Za-z0-9_]+_core\.cob`' docs/STATUS.md | sort -u | wc -l | tr -d ' ')
echo "curated modules: $curated ; documented in STATUS.md: $documented"

echo
echo "=== Traceability status ==="
for st in implemented partial missing; do
    n=$(grep -cE "^\| [A-Z0-9-]+ \|.*\| $st \|" docs/TRACEABILITY.md)
    echo "$st: $n"
done

echo
echo "=== Volume ==="
./scripts/loc_report.sh --quality | grep -E "curated|generated|Total|share" | head

echo
echo "=== CI baseline ==="
awk '$1 !~ /^#/ {s+=$2} END {print "shell suites total:", s}' tests/baseline_counts.txt
echo "gateway: $(awk '$1=="gateway"{print $2}' tests/baseline_counts.txt)"