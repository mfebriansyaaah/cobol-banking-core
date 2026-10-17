#!/bin/bash
# Env coverage check: every configuration knob the code reads must be
# documented in middleware/.env.example, so operators can discover it.
# Covers gateway knobs (process.env.X with a fallback default) and core
# knobs (COBOL env_or settings). Fails naming the undocumented variable.
# Usage: ./tests/env_check.sh

fail=0
EXAMPLE="middleware/.env.example"

# An active KEY=default line counts as documented (commented-out keys do
# not: every knob in this file ships a working default).
documented() {
    grep -qE "^$1=" "$EXAMPLE"
}

# Gateway: process.env.NAME (uppercase names only; lowercase property
# accesses like req.ip are not configuration).
for v in $(grep -rhoE "process\.env\.[A-Z][A-Z0-9_]*" middleware/src/*.js | sed 's/.*env\.//' | sort -u); do
    if ! documented "$v"; then
        echo "env check: '$v' is read by the gateway but missing from $EXAMPLE"
        fail=1
    fi
done

# Core: CALL "env_or"/"env_or_raw" USING BY REFERENCE "NAME" (the first quoted literal).
for v in $(grep -rhoE 'CALL "env_or(_raw)?" USING BY REFERENCE "[A-Z_]+"' cobol/src/*.cob | grep -oE '"[A-Z_]+"' | tr -d '"' | sort -u); do
    if ! documented "$v"; then
        echo "env check: '$v' is read by the COBOL core but missing from $EXAMPLE"
        fail=1
    fi
done

[ "$fail" -eq 0 ] || { echo "ENV CHECK FAILED"; exit 1; }
echo "env check OK"
