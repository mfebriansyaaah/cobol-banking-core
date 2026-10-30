#!/usr/bin/env bash
# Gate detection probes.
#
# A gate that has never been seen to fail is not a gate, it is a decoration.
# This script takes a throwaway copy of the repo (git archive HEAD), breaks one
# thing at a time, and records which gate notices.
#
# It does not test the code under test; it tests the *checks*. The expected
# result for each probe lives in tests/probes/expectations.txt and is compared
# against reality:
#
#   detected -> at least one gate exited non-zero
#   missed   -> every static gate passed on deliberately broken code
#
# A "missed" in the expectations file is a recorded capability gap, not a
# pass. When Fase 2 adds a gate that closes it, the probe starts reporting
# "detected", this script fails, and the expectation must be updated on
# purpose. That is the ratchet.
#
# Scope: the static layer only (syntax + manifest + route/dispatch + per-route
# auth + action coverage + bind slots + DB inventory + case/helper checks).
# Runtime suites are not run here, so a probe that only a DB or gateway test
# would catch shows up as "missed" — that is accurate for the static layer and
# is the point.
#
# Usage: tests/probes/run_probes.sh
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EXPECT_FILE="$ROOT/tests/probes/expectations.txt"

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/gate-probes.XXXXXX")"
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT INT TERM

# Never mutate the real checkout, whatever happens to the variables above.
case "$SANDBOX/" in
    "$ROOT"/*)
        echo "FAIL: refusing to run probes inside the repository ($SANDBOX)" >&2
        exit 2
        ;;
esac

if [ ! -f "$EXPECT_FILE" ]; then
    echo "FAIL: missing $EXPECT_FILE" >&2
    exit 2
fi

GATES=(js_syntax manifest route_dispatch route_conflicts action_coverage case_actions test_helpers auth_guard route_auth bind_slots suite_coverage)

# --- gates under test -------------------------------------------------------
# Each returns 0 when it believes the code is fine, non-zero when it refuses.

gate_js_syntax() {
    node --no-warnings --experimental-vm-modules scripts/check_js_syntax.mjs . >/dev/null 2>&1
}

gate_manifest() { node scripts/check_manifest.mjs . >/dev/null 2>&1; }
gate_route_dispatch() { node scripts/check_route_dispatch.mjs . >/dev/null 2>&1; }
gate_route_conflicts() { node scripts/check_route_conflicts.mjs . >/dev/null 2>&1; }
gate_action_coverage() { node scripts/check_action_coverage.mjs . >/dev/null 2>&1; }
gate_case_actions() { node scripts/check_case_actions.mjs . >/dev/null 2>&1; }
gate_test_helpers() { node scripts/check_test_helpers.mjs . >/dev/null 2>&1; }
gate_route_auth() { node scripts/check_route_auth.mjs . >/dev/null 2>&1; }
gate_bind_slots() { node scripts/check_bind_slots.mjs . >/dev/null 2>&1; }
gate_suite_coverage() { node scripts/check_suite_coverage.mjs . >/dev/null 2>&1; }

# Same check as scripts/ci/sast.sh: one route file must mention tokenIdentity
# somewhere. Note it is per file, not per route — probe P3 measures that.
gate_auth_guard() {
    local f
    for f in middleware/src/routes/*.js; do
        case "$(basename "$f")" in index.js) continue ;; esac
        grep -q 'tokenIdentity' "$f" || return 1
    done
    return 0
}

# --- mutations --------------------------------------------------------------
# Each mutator runs with cwd = sandbox and must leave a syntactically valid
# tree except where the probe is about syntax.

mut_p1_broken_route_syntax() {
    node <<'EOF'
const fs = require('fs');
const p = 'middleware/src/routes/account.js';
let s = fs.readFileSync(p, 'utf8');
if (!s.includes('fields: [')) throw new Error('anchor not found');
s = s.replace('fields: [', 'fields: [ {{ ');
fs.writeFileSync(p, s);
EOF
}

mut_p2_duplicate_route() {
    node <<'EOF'
const fs = require('fs');
const p = 'middleware/src/routes/account.js';
const lines = fs.readFileSync(p, 'utf8').split('\n');
const i = lines.findIndex((l) => /^\s*\{ method: .*fields: \[.*\] \},\s*$/.test(l));
if (i < 0) throw new Error('single-line route not found');
lines.splice(i + 1, 0, lines[i]);
fs.writeFileSync(p, lines.join('\n'));
EOF
}

# One endpoint loses its identity; the file still has plenty of others.
mut_p3a_one_route_without_identity() {
    node <<'EOF'
const fs = require('fs');
const p = 'middleware/src/routes/account.js';
let s = fs.readFileSync(p, 'utf8');
const next = s.replace(/tokenIdentity: '[^']*', /, '');
if (next === s) throw new Error('tokenIdentity anchor not found');
fs.writeFileSync(p, next);
EOF
}

# The whole file loses identity. Coarser than P3a on purpose.
mut_p3b_whole_route_file_without_identity() {
    node <<'EOF'
const fs = require('fs');
const p = 'middleware/src/routes/account.js';
let s = fs.readFileSync(p, 'utf8');
s = s.replace(/tokenIdentity: '[^']*', /g, '').replace(/tokenIdentity: '[^']*'/g, '');
if (s.includes('tokenIdentity')) throw new Error('tokenIdentity not fully removed');
fs.writeFileSync(p, s);
EOF
}

# A new endpoint reuses an existing dispatch prefix (ACC_) but no COBOL module
# implements the action. check_route_dispatch's startsWith() accepts it.
mut_p4_action_without_cobol_handler() {
    node <<'EOF'
const fs = require('fs');
const p = 'middleware/src/routes/account.js';
let s = fs.readFileSync(p, 'utf8');
const anchor = 'export const ACCOUNT_ROUTES = [\n';
if (!s.includes(anchor)) throw new Error('route array anchor not found');
const route = "  { method: 'post', path: '/accounts/probe', action: 'ACC_PROBE_MISSING', tokenIdentity: 'actor', fields: [ACTOR] },\n";
fs.writeFileSync(p, s.replace(anchor, anchor + route));
EOF
}

# The real P0-2 shape: a value moved into a slot the following CALL does not
# pass. The query is prepared with an empty parameter, so it silently matches
# nothing. check_bind_slots computes "was this slot passed?" and catches it.
mut_p5_dead_bind_slot() {
    node <<'EOF'
const fs = require('fs');
const path = require('path');
const dir = 'cobol/src';
for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.cob')).sort()) {
  const lines = fs.readFileSync(path.join(dir, file), 'utf8').split('\n');
  for (let i = 0; i < lines.length; i += 1) {
    const w = lines[i].match(/\bMOVE\s+([A-Z0-9-]+)\s+TO\s+WS-BIND-1\b/);
    if (!w) continue;
    // Find the next CALL and the slots it passes.
    let j = i + 1;
    while (j < lines.length && !/CALL\s+"SQL_PREPARE_EXEC[A-Z_]*"/.test(lines[j])) j += 1;
    if (j >= lines.length) continue;
    const slots = new Set();
    let k = j;
    do {
      for (const m of lines[k].matchAll(/BY\s+REFERENCE\s+WS-BIND-(\d+)/g)) slots.add(Number(m[1]));
      k += 1;
    } while (k < lines.length && !/END-CALL/.test(lines[k - 1]) && k < j + 10);
    if (slots.has(6)) continue; // this call would read slot 6, so pick another site
    lines[i] = lines[i].replace('TO WS-BIND-1', 'TO WS-BIND-6');
    fs.writeFileSync(path.join(dir, file), lines.join('\n'));
    process.exit(0);
  }
}
throw new Error('no single-slot call site found');
EOF
}

# A true swap: the value that belonged in slot 1 goes to slot 2 and vice versa.
# Both slots are passed, so nothing static can tell the order is wrong.
mut_p5b_swapped_bind_slots() {
    node <<'EOF'
const fs = require('fs');
const path = require('path');
const dir = 'cobol/src';
for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.cob')).sort()) {
  const lines = fs.readFileSync(path.join(dir, file), 'utf8').split('\n');
  for (let i = 0; i < lines.length - 1; i += 1) {
    if (!/\bMOVE\s+[A-Z0-9-]+\s+TO\s+WS-BIND-1\b/.test(lines[i])) continue;
    if (!/\bMOVE\s+[A-Z0-9-]+\s+TO\s+WS-BIND-2\b/.test(lines[i + 1])) continue;
    lines[i] = lines[i].replace('TO WS-BIND-1', 'TO WS-BIND-TMP');
    lines[i + 1] = lines[i + 1].replace('TO WS-BIND-2', 'TO WS-BIND-1');
    lines[i] = lines[i].replace('TO WS-BIND-TMP', 'TO WS-BIND-2');
    fs.writeFileSync(path.join(dir, file), lines.join('\n'));
    process.exit(0);
  }
}
throw new Error('no adjacent BIND-1/BIND-2 pair found');
EOF
}

# A DB suite disappears. run_all.sh globs the directory, so the denominator
# quietly shrinks and no gate mentions the missing suite.
mut_p6_deleted_db_suite() {
    rm -f tests/db/account_db_tests.sh
}

# --- runner -----------------------------------------------------------------

PROBES=(
    p1_broken_route_syntax
    p2_duplicate_route
    p3a_one_route_without_identity
    p3b_whole_route_file_without_identity
    p4_action_without_cobol_handler
    p5_dead_bind_slot
    p5b_swapped_bind_slots
    p6_deleted_db_suite
)

declare -A EXPECTED=()
KNOWN_KEYS=()
while IFS='=' read -r key value; do
    case "$key" in
        ''|'#'*) continue ;;
    esac
    value="${value//[[:space:]]/}"
    case "$value" in
        detected|missed) ;;
        *)
            echo "FAIL: $EXPECT_FILE: '$key' must be detected or missed, got '$value'" >&2
            exit 2
            ;;
    esac
    EXPECTED["$key"]="$value"
    KNOWN_KEYS+=("$key")
done < "$EXPECT_FILE"

printf '%-42s %-10s %-10s %s\n' "probe" "expected" "actual" "caught by"
printf '%-42s %-10s %-10s %s\n' "------------------------------------------" "----------" "----------" "---------"

mismatches=0
missed=0
detected=0
for probe in "${PROBES[@]}"; do
    rm -rf "$SANDBOX"
    mkdir -p "$SANDBOX"
    if ! git -C "$ROOT" archive HEAD | tar -x -C "$SANDBOX"; then
        echo "FAIL: could not snapshot HEAD into sandbox" >&2
        exit 2
    fi

    mutator="mut_${probe}"
    if ! ( cd "$SANDBOX" && "$mutator" ) >/dev/null 2>&1; then
        echo "FAIL: $probe: mutation could not be applied" >&2
        exit 2
    fi

    caught=""
    for gate in "${GATES[@]}"; do
        if ! ( cd "$SANDBOX" && "gate_${gate}" ) >/dev/null 2>&1; then
            caught="${caught:+$caught,}$gate"
        fi
    done

    if [ -n "$caught" ]; then
        actual="detected"
        detected=$((detected + 1))
    else
        actual="missed"
        missed=$((missed + 1))
    fi

    if [ -z "${EXPECTED[$probe]:-}" ]; then
        printf '%-42s %-10s %-10s %s\n' "$probe" "(none)" "$actual" "${caught:-none}"
        echo "FAIL: $probe has no expectation in tests/probes/expectations.txt" >&2
        mismatches=$((mismatches + 1))
        continue
    fi

    printf '%-42s %-10s %-10s %s\n' "$probe" "${EXPECTED[$probe]}" "$actual" "${caught:-none}"
    if [ "${EXPECTED[$probe]}" != "$actual" ]; then
        mismatches=$((mismatches + 1))
        if [ "${EXPECTED[$probe]}" = "missed" ]; then
            echo "  ^ improvement: a gate now catches this. Update expectations.txt deliberately." >&2
        else
            echo "  ^ regression: this was caught before and is not any more." >&2
        fi
    fi
done

for key in "${KNOWN_KEYS[@]}"; do
    printf '%s\n' "${PROBES[@]}" | grep -qx "$key" && continue
    echo "FAIL: expectation '$key' has no matching probe" >&2
    mismatches=$((mismatches + 1))
done

echo
echo "probes: ${#PROBES[@]} | detected: $detected | missed: $missed"
if [ "$mismatches" -ne 0 ]; then
    echo "FAIL: $mismatches probe(s) do not match tests/probes/expectations.txt"
    exit 1
fi
echo "OK: every probe matched its recorded expectation"
exit 0
