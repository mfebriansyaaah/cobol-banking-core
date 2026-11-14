// SQL bind-slot guard (extended DRY-06A: inline CALLs and shared wrappers).
//
// SQL_PREPARE_EXEC(sql, count, bind1..bindN) reads its arguments positionally.
// A value moved into a WS-BIND-n that the following CALL does not pass can
// never reach the query: the statement is prepared with an empty (or stale)
// parameter. That is exactly the P0-2 transfer defect — the sender lookup moved
// the email into WS-BIND-6 while the call passed WS-BIND-1..5, so every transfer
// resolved "no such account" and returned 404.
//
// Two rules per call, both purely positional:
//   1. every slot written between the statement and the CALL must be passed;
//   2. the passed list must be exactly 1..k in order.
// Rule 2 matters because the arguments are read left to right: a list like
// [6,1,2,3,4] both starts at a stale slot and shifts every real value one place
// to the right, so the query runs with the wrong parameters even though every
// slot it names was written.
//
// Shared wrappers (cobol/copy/sql_exec_*.cpy) obey the same contract through
// PERFORM SQL-EXEC-n / SQL-EXEC-ROWS-n:
//   1. binds 1..n (exactly, in order) are MOVEd contiguously before PERFORM;
//   2. WS-PREP-SQL is assigned (MOVE literal or STRING build) before PERFORM;
//   3. for MOVE literals, the '?' placeholder count equals n (STRING-built
//      queries cannot be counted statically; binds + assignment are checked).
//
// Rollout ratchet (tests/sql_wrapper_baseline.txt): per-module remaining
// inline CALL counts. A module must never gain a new inline CALL site —
// convert to the wrapper instead. Regenerate deliberately with --write.
//
// Scope: one module at a time, one arithmetic fact — "which slot reaches which
// argument?". A true swap (value in slot 1 vs slot 2) is semantically invisible
// here and is deliberately not claimed; see tests/probes/expectations.txt.
//
// Usage: node scripts/check_bind_slots.mjs [--write] [ROOT]
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
let root = '.';
let write = false;
for (const a of args) {
  if (a === '--write') write = true;
  else if (a === '--help' || a === '-h') {
    console.log('usage: check_bind_slots.mjs [--write] [ROOT]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else root = a;
}
root = path.resolve(root);
const cobolDir = path.join(root, 'cobol', 'src');
const baseFile = path.join(root, 'tests', 'sql_wrapper_baseline.txt');

const SQL_MOVE_RE = /^\s*MOVE\s+"[^"]*"\s+TO\s+WS-PREP-SQL/;
const SQL_STRING_RE = /\bINTO\s+WS-PREP-SQL\b/;
const BIND_WRITE_RE = /\bMOVE\s+([A-Z0-9-]+)\s+TO\s+WS-BIND-(\d+)/;
const SQL_CALL_RE = /\bCALL\s+"(SQL_PREPARE_EXEC[A-Z_]*)"/;
const BIND_PASS_RE = /BY\s+REFERENCE\s+WS-BIND-(\d+)/g;
const END_CALL_RE = /\bEND-CALL\b/;
const WRAP_RE = /^\s*PERFORM\s+(SQL-EXEC(?:-ROWS)?-(\d+))\s*$/;
const PARA_RE = /^ {7,8}[A-Z][A-Z0-9-]+\.\s*$/;
const DIVISION_RE = /^(?:.*\bDIVISION\b|.*\bSECTION\b)\.\s*$/;
const LITERAL_RE = /MOVE\s+"((?:[^"]|"")*)"\s+TO\s+WS-PREP-SQL/;

const failures = [];
const listFailures = [];
const wrapFailures = [];
const notes = [];
let callsChecked = 0;
let wrapsChecked = 0;
const inlineCallsByModule = {};

for (const file of readdirSync(cobolDir)
  .filter((f) => f.endsWith('.cob'))
  .sort()) {
  const lines = readFileSync(path.join(cobolDir, file), 'utf8').split('\n');
  const module = file.replace(/\.cob$/, '');
  inlineCallsByModule[module] = 0;
  let pendingBinds = [];

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];

    // A new statement is being built; binds written before it belong to the
    // previous statement and must not be attributed to the next call.
    if (SQL_MOVE_RE.test(line) || SQL_STRING_RE.test(line)) {
      pendingBinds = [];
      continue;
    }

    const write = line.match(BIND_WRITE_RE);
    if (write) {
      pendingBinds.push({ slot: Number(write[2]), source: write[1], line: i + 1 });
      continue;
    }

    const wrap = line.match(WRAP_RE);
    if (wrap) {
      wrapsChecked += 1;
      const arity = Number(wrap[2]);
      // Collect contiguous bind writes immediately above (blanks allowed).
      const staged = [];
      let k = i - 1;
      while (k >= 0 && lines[k].trim() === '') k -= 1;
      while (k >= 0) {
        const m = lines[k].match(BIND_WRITE_RE);
        if (!m || !/^\s*MOVE\b/.test(lines[k])) break;
        staged.unshift({ slot: Number(m[2]), line: k + 1 });
        k -= 1;
        while (k >= 0 && lines[k].trim() === '') k -= 1;
      }
      const slots = staged.map((s) => s.slot);
      const want = Array.from({ length: arity }, (_, idx) => idx + 1);
      if (arity > 0 && (slots.length !== arity || slots.some((s, idx) => s !== idx + 1))) {
        wrapFailures.push({
          file,
          line: i + 1,
          name: wrap[1],
          detail: `staged [${slots.join(', ') || 'none'}], expected [${want.join(', ')}]`,
        });
      }
      // Find the WS-PREP-SQL assignment above the binds.
      let assign = null;
      let q = k;
      let guard = 0;
      while (q >= 0 && guard < 60) {
        guard += 1;
        const l = lines[q];
        if (PARA_RE.test(l) || DIVISION_RE.test(l)) break;
        const lit = l.match(LITERAL_RE);
        if (lit) {
          assign = { kind: 'literal', sql: lit[1].replace(/""/g, '"'), line: q + 1 };
          break;
        }
        if (SQL_STRING_RE.test(l)) {
          assign = { kind: 'string', line: q + 1 };
          break;
        }
        q -= 1;
      }
      if (!assign) {
        wrapFailures.push({
          file,
          line: i + 1,
          name: wrap[1],
          detail: 'no WS-PREP-SQL assignment (MOVE literal or STRING build) found above',
        });
      } else if (assign.kind === 'literal') {
        const holes = (assign.sql.match(/\?/g) || []).length;
        if (holes !== arity) {
          wrapFailures.push({
            file,
            line: i + 1,
            name: wrap[1],
            detail: `literal has ${holes} placeholder(s), wrapper binds ${arity}`,
          });
        }
      } else {
        notes.push(`${file}:${i + 1} ${wrap[1]}: STRING-built query, binds checked, placeholders not counted`);
      }
      pendingBinds = [];
      continue;
    }

    const call = line.match(SQL_CALL_RE);
    if (!call) continue;

    // The bind list may wrap over several lines; read until END-CALL.
    const ordered = [];
    const passed = new Set();
    let j = i;
    do {
      for (const m of lines[j].matchAll(BIND_PASS_RE)) {
        passed.add(Number(m[1]));
        ordered.push(Number(m[1]));
      }
      j += 1;
    } while (j < lines.length && !END_CALL_RE.test(lines[j - 1]) && j < i + 10);

    callsChecked += 1;
    inlineCallsByModule[module] += 1;

    if (ordered.length && ordered.some((slot, idx) => slot !== idx + 1)) {
      listFailures.push({ file, callLine: i + 1, call: call[1], ordered });
    }

    for (const bind of pendingBinds) {
      if (!passed.has(bind.slot)) {
        failures.push({
          file,
          line: bind.line,
          source: bind.source,
          slot: bind.slot,
          callLine: i + 1,
          call: call[1],
          passed: [...passed].sort((a, b) => a - b),
        });
      }
    }
    pendingBinds = [];
  }
}

const actual = Object.fromEntries(Object.entries(inlineCallsByModule).sort(([a], [b]) => (a < b ? -1 : 1)));
let want = null;
if (existsSync(baseFile)) {
  want = {};
  for (const line of readFileSync(baseFile, 'utf8').split('\n')) {
    const m = line.match(/^([A-Za-z0-9_]+)=(\d+)$/);
    if (m) want[m[1]] = Number(m[2]);
  }
}

if (write) {
  const header =
    '# SQL wrapper rollout baseline (module -> remaining inline CALL sites).\n' +
    '# Counts from scripts/check_bind_slots.mjs. Never add a site back;\n' +
    '# convert to PERFORM SQL-EXEC-n instead, then --write after review.\n';
  writeFileSync(
    baseFile,
    header +
      Object.entries(actual)
        .map(([m, n]) => `${m}=${n}\n`)
        .join(''),
  );
  console.log(`wrote ${baseFile}`);
}

let failed = false;

if (failures.length) {
  failed = true;
  console.error('BIND VALUES THAT NEVER REACH THE QUERY:');
  for (const f of failures) {
    console.error(`  cobol/src/${f.file}:${f.line}  ${f.source} -> WS-BIND-${f.slot}`);
    console.error(
      `    ${f.call} at line ${f.callLine} passes only [${f.passed.join(', ')}]; slot ${f.slot} is never read`,
    );
  }
  console.error(`\n${failures.length} dead bind write(s) across ${callsChecked} SQL call(s)`);
  console.error('A value written to a slot the call does not pass is silently dropped.');
}

if (listFailures.length) {
  failed = true;
  console.error('BIND LISTS THAT ARE NOT 1..k IN ORDER:');
  for (const f of listFailures) {
    console.error(`  cobol/src/${f.file}:${f.callLine}  ${f.call}`);
    console.error(`    passes [${f.ordered.join(', ')}]; expected [${f.ordered.map((_, idx) => idx + 1).join(', ')}]`);
  }
  console.error(`\n${listFailures.length} rotated bind list(s) across ${callsChecked} SQL call(s)`);
  console.error('Arguments are positional: a rotated list feeds the wrong value to each placeholder.');
}

if (wrapFailures.length) {
  failed = true;
  console.error('SHARED WRAPPER SITES THAT BREAK THE CONTRACT:');
  for (const f of wrapFailures) {
    console.error(`  cobol/src/${f.file}:${f.line}  PERFORM ${f.name}: ${f.detail}`);
  }
  console.error(`\n${wrapFailures.length} bad wrapper site(s) across ${wrapsChecked} PERFORM(s)`);
}

if (!want) {
  failed = true;
  console.error(`FAIL: ${baseFile} missing (run with --write once, after review)`);
} else {
  for (const [module, count] of Object.entries(actual)) {
    if (want[module] === undefined) {
      failed = true;
      console.error(`FAIL: wrapper baseline missing ${module} (now ${count} inline CALLs; --write after review)`);
    } else if (count > want[module]) {
      failed = true;
      console.error(
        `FAIL: wrapper baseline exceeded for ${module}: baseline=${want[module]} actual=${count} (convert to PERFORM SQL-EXEC-n instead)`,
      );
    }
  }
}

if (failed) process.exit(1);

for (const n of notes) console.log(`note: ${n}`);
console.log(
  `OK: ${callsChecked} SQL call(s) bind only slots they pass, in 1..k order; ${wrapsChecked} wrapper PERFORM(s) stage exactly 1..n`,
);
