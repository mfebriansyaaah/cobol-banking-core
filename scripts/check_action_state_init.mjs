// Cross-action state gate (numeric-hardening follow-up): with IS INITIAL,
// WORKING-STORAGE no longer persists across --serve CALLs. An ACTION that
// reads a field written only by a DIFFERENT action used to work by accident
// (stale copy) and now fails deterministically. Real case: statement_core
// ACTION-RUN-GENERATE read WS-RUN-ID, written only by ACTION-RUN-START;
// fixed by explicit per-action init (MOVE WS-P1-TRIMMED TO WS-RUN-ID).
// Same class fixed in loan_core (WS-TMP-AMT -> WS-LOAN-AMT in DISBURSE/REPAY).
//
// Rule: for every ACTION paragraph, every WS-/LS- field it reads must be
// written in its reachable set (own body + MAIN-LOGIC entry + transitively
// PERFORMed non-ACTION paragraphs, COPY-expanded), unless the field is
// conventional (TRIM-ALL outputs, SQL bridge slots, reset/flag idioms).
// A field written in exactly one other ACTION and read here fails the gate.
// Usage: node scripts/check_action_state_init.mjs [root]
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { expandCopybooks } from './lib/cobol_source.mjs';

const ROOT = path.resolve(process.argv[2] || '.');
const srcDir = path.join(ROOT, 'cobol', 'src');
const copyDir = path.join(ROOT, 'cobol', 'copy');

const PARA_RE = /^ {7,8}([A-Z][A-Z0-9-]+)\.\s*$/;
const FIELD_RE = /\b([A-Z][A-Z0-9-]*)\b/g;
const KEYWORDS = new Set(
  'TO BY SIZE SPACE SPACES DELIMITED VALUE VALUES TRUE FALSE ZERO ZEROES ZEROS THEN ELSE END NOT AND OR EXIT PERFORM MOVE COMPUTE INTO UNSTRING STRING CALL USING ACCEPT SET GOBACK IF EVALUATE WHEN OTHER CONTINUE ADD SUBTRACT MULTIPLY DIVIDE INSPECT TALLYING REPLACING ALL LEADING TRAILING FOR VARYING UNTIL WHILE WITH POINTER ON OVERFLOW ERROR OUTPUT_TOO_LARGE ROUNDED EQUAL GREATER LESS THAN NUMVAL TRIM LENGTH FUNCTION CURRENT-DATE'.split(
    ' ',
  ),
);

// Fields that are safe by convention: TRIM-ALL outputs, SQL bridge slots
// (covered by check_cobol_field_sizes + check_bind_slots), and the reset /
// guard idioms checked by their own gates.
const CONVENTIONAL = new Set(['WS-RESULT', 'WS-PREP-SQL', 'WS-QUERY', 'WS-ERR', 'WS-BAD', 'WS-ALLOWED', 'WS-OUT-POS']);
for (let i = 1; i <= 8; i++) {
  CONVENTIONAL.add(`WS-P${i}-TRIMMED`);
  CONVENTIONAL.add(`WS-P${i}-LEN`);
}
for (let i = 1; i <= 8; i++) CONVENTIONAL.add(`WS-BIND-${i}`);
for (let i = 1; i <= 4; i++) CONVENTIONAL.add(`WS-CALL-P${i}`);
CONVENTIONAL.add('WS-CALL-ACTION');
CONVENTIONAL.add('WS-CALL-OUT');

function isField(w) {
  return /^(WS|LS)-[A-Z0-9-]+$/.test(w) && !KEYWORDS.has(w);
}

function writesIn(body) {
  const out = new Set();
  const codeOnly = body
    .split('\n')
    .map((l) => l.split('*>')[0])
    .join('\n');
  // Multi-line UNSTRING ... INTO list.
  for (const m of codeOnly.matchAll(/\bUNSTRING\b([\s\S]*?)(?:END-UNSTRING|\.(?:\s|$))/g)) {
    const seg = m[1];
    const idx = seg.indexOf('INTO');
    if (idx !== -1) {
      for (const fm of seg.slice(idx).matchAll(FIELD_RE)) {
        const w = fm[1];
        if (isField(w) && w !== 'DELIMITED' && w !== 'BY' && w !== 'SIZE' && w !== 'SPACE' && w !== 'POINTER') out.add(w);
      }
    }
  }
  for (const line of codeOnly.split('\n')) {
    for (const m of line.matchAll(/\bMOVE\b(.*?)\bTO\b(.*)$/g)) {
      for (const fm of m[2].matchAll(FIELD_RE)) if (isField(fm[1])) out.add(fm[1]);
    }
    for (const m of line.matchAll(/\bCOMPUTE\s+([A-Z][A-Z0-9-]*)/g)) out.add(m[1]);
    if (!/\bUNSTRING\b/.test(line)) {
      for (const m of line.matchAll(/\bINTO\s+([A-Z][A-Z0-9-]*)/g)) if (isField(m[1])) out.add(m[1]);
    }
    for (const m of line.matchAll(/\bSET\s+([A-Z][A-Z0-9-]*)\s+TO\b/g)) if (isField(m[1])) out.add(m[1]);
    for (const m of line.matchAll(/\bACCEPT\s+([A-Z][A-Z0-9-]*)/g)) if (isField(m[1])) out.add(m[1]);
    for (const m of line.matchAll(/\bCALL\s+"[^"]+"\s+USING\b(.*)/g)) {
      for (const fm of m[1].matchAll(FIELD_RE)) if (isField(fm[1])) out.add(fm[1]);
    }
  }
  return out;
}

function readsIn(body) {
  const out = new Set();
  const codeOnly = body
    .split('\n')
    .map((l) => l.split('*>')[0])
    .join('\n');
  for (const m of codeOnly.matchAll(FIELD_RE)) if (isField(m[1])) out.add(m[1]);
  for (const w of writesIn(body)) out.delete(w);
  return out;
}

const failures = [];
let checked = 0;

for (const f of readdirSync(srcDir)
  .filter((x) => x.endsWith('.cob'))
  .sort()) {
  const raw = readFileSync(path.join(srcDir, f), 'utf8');
  const src = expandCopybooks(raw, { copyDir });
  const lines = src.split('\n');
  const bounds = [];
  lines.forEach((l, i) => {
    const m = PARA_RE.exec(l);
    if (m) bounds.push([i, m[1]]);
  });
  bounds.push([lines.length, null]);
  const paras = new Map();
  for (let b = 0; b < bounds.length - 1; b++) {
    if (bounds[b][1]) paras.set(bounds[b][1], lines.slice(bounds[b][0], bounds[b + 1][0]).join('\n'));
  }
  const reachWrites = (entry, depth = 0, seen = new Set()) => {
    if (seen.has(entry) || depth > 6 || !paras.has(entry)) return new Set();
    seen.add(entry);
    let w = new Set(writesIn(paras.get(entry)));
    for (const m of paras.get(entry).matchAll(/PERFORM\s+([A-Z][A-Z0-9-]+)/g)) {
      const h = m[1];
      // Do not cross ACTION boundaries: callee actions run on their own CALL.
      if (h.startsWith('ACTION-') || h === 'MAIN-LOGIC') continue;
      for (const x of reachWrites(h, depth + 1, seen)) w.add(x);
    }
    return w;
  };
  const mainWrites = paras.has('MAIN-LOGIC') ? reachWrites('MAIN-LOGIC') : new Set();
  for (const [pname, body] of paras) {
    if (!pname.startsWith('ACTION-')) continue;
    checked += 1;
    let reachable = new Set([...writesIn(body), ...mainWrites]);
    for (const m of body.matchAll(/PERFORM\s+([A-Z][A-Z0-9-]+)/g)) {
      const h = m[1];
      if (h.startsWith('ACTION-') || h === 'MAIN-LOGIC') continue;
      for (const x of reachWrites(h)) reachable.add(x);
    }
    for (const fld of readsIn(body)) {
      if (CONVENTIONAL.has(fld) || reachable.has(fld)) continue;
      const writers = [];
      for (const [p2, b2] of paras) {
        if (p2.startsWith('ACTION-') && writesIn(b2).has(fld)) writers.push(p2);
      }
      if (writers.length === 1 && writers[0] !== pname) {
        failures.push(`${f}: ${fld} read in ${pname}, only written in ${writers[0]} (stale across --serve CALLs?)`);
      }
    }
  }
}

if (failures.length) {
  for (const msg of failures) console.error(`FAIL: ${msg}`);
  process.exit(1);
}
console.log(`OK: ${checked} ACTION paragraphs initialize the state they read`);
