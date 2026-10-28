// SQL bind-slot guard.
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
// Scope: one module at a time, one arithmetic fact — "which slot reaches which
// argument?". A true swap (value in slot 1 vs slot 2) is semantically invisible
// here and is deliberately not claimed; see tests/probes/expectations.txt.
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.argv[2] || '.');
const cobolDir = path.join(ROOT, 'cobol', 'src');

const SQL_MOVE_RE = /^\s*MOVE\s+"[^"]*"\s+TO\s+WS-PREP-SQL/;
const SQL_STRING_RE = /\bINTO\s+WS-PREP-SQL\b/;
const BIND_WRITE_RE = /\bMOVE\s+([A-Z0-9-]+)\s+TO\s+WS-BIND-(\d+)/;
const SQL_CALL_RE = /\bCALL\s+"(SQL_PREPARE_EXEC[A-Z_]*)"/;
const BIND_PASS_RE = /BY\s+REFERENCE\s+WS-BIND-(\d+)/g;
const END_CALL_RE = /\bEND-CALL\b/;

const failures = [];
const listFailures = [];
let callsChecked = 0;

for (const file of readdirSync(cobolDir).filter((f) => f.endsWith('.cob')).sort()) {
  const lines = readFileSync(path.join(cobolDir, file), 'utf8').split('\n');
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

let failed = false;

if (failures.length) {
  failed = true;
  console.error('BIND VALUES THAT NEVER REACH THE QUERY:');
  for (const f of failures) {
    console.error(
      `  cobol/src/${f.file}:${f.line}  ${f.source} -> WS-BIND-${f.slot}`
    );
    console.error(
      `    ${f.call} at line ${f.callLine} passes only [${f.passed.join(', ')}]; slot ${f.slot} is never read`
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

if (failed) process.exit(1);

console.log(`OK: ${callsChecked} SQL call(s) bind only slots they pass, in 1..k order`);
