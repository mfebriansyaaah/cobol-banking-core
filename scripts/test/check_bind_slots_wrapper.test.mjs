// SQL wrapper gate pins (DRY-06A). No database, no build.
//
// PERFORM SQL-EXEC-n / SQL-EXEC-ROWS-n must stage exactly binds 1..n
// immediately before, with WS-PREP-SQL assigned and (for literal SQL) a
// matching '?' placeholder count. Fixture roots carry their own baseline.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const GATE = path.join(ROOT, 'scripts', 'check_bind_slots.mjs');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

function makeRoot(files, baseline = null) {
  const d = mkdtempSync(path.join(tmpdir(), 'bindexec-'));
  dirs.push(d);
  mkdirSync(path.join(d, 'cobol', 'src'), { recursive: true });
  for (const [name, body] of Object.entries(files)) {
    writeFileSync(path.join(d, 'cobol', 'src', name), body);
  }
  const counts = {};
  for (const [name, body] of Object.entries(files)) {
    counts[name.replace(/\.cob$/, '')] = (body.match(/CALL\s+"SQL_PREPARE_EXEC/g) || []).length;
  }
  const want = baseline ?? counts;
  const lines = ['# SQL wrapper rollout baseline (module -> remaining inline CALL sites). Only shrinks.'];
  for (const [m, n] of Object.entries(want)) lines.push(`${m}=${n}`);
  mkdirSync(path.join(d, 'tests'), { recursive: true });
  writeFileSync(path.join(d, 'tests', 'sql_wrapper_baseline.txt'), `${lines.join('\n')}\n`);
  return d;
}

function run(root) {
  try {
    const out = execFileSync(process.execPath, [GATE, root], { encoding: 'utf8' });
    return { status: 0, out };
  } catch (e) {
    return { status: e.status ?? 1, out: String(e.stdout || '') + String(e.stderr || '') };
  }
}

const GOOD = `        MAIN-LOGIC.
            MOVE "SELECT 1 FROM t WHERE a = ? AND b = ?" TO WS-PREP-SQL
            MOVE X TO WS-BIND-1
            MOVE Y TO WS-BIND-2
            PERFORM SQL-EXEC-2
            IF WS-RESULT = "ERROR|NO_DATA"
                EXIT PARAGRAPH
            END-IF.
`;

test('correct wrapper use passes', () => {
  const d = makeRoot({ 'ok.cob': GOOD });
  const r = run(d);
  assert.equal(r.status, 0, r.out);
  assert.match(r.out, /OK:/);
});

test('missing bind slot fails', () => {
  const bad = GOOD.replace('            MOVE Y TO WS-BIND-2\n', '');
  const d = makeRoot({ 'bad.cob': bad });
  const r = run(d);
  assert.equal(r.status, 1);
  assert.match(r.out, /SQL-EXEC-2.*staged \[1\], expected \[1, 2\]/s);
});

test('rotated bind slots fail', () => {
  const bad = GOOD.replace('MOVE X TO WS-BIND-1', 'MOVE X TO WS-BIND-3');
  const d = makeRoot({ 'bad.cob': bad });
  const r = run(d);
  assert.equal(r.status, 1);
});

test('placeholder count mismatch fails', () => {
  const bad = GOOD.replace('a = ? AND b = ?', 'a = ? AND b = ? AND c = ?');
  const d = makeRoot({ 'bad.cob': bad });
  const r = run(d);
  assert.equal(r.status, 1);
  assert.match(r.out, /literal has 3 placeholder/);
});

test('missing WS-PREP-SQL assignment fails', () => {
  const bad = GOOD.replace('            MOVE "SELECT 1 FROM t WHERE a = ? AND b = ?" TO WS-PREP-SQL\n', '');
  const d = makeRoot({ 'bad.cob': bad });
  const r = run(d);
  assert.equal(r.status, 1);
  assert.match(r.out, /WS-PREP-SQL/);
});

test('STRING-built queries check binds without placeholder counting', () => {
  const src = `        MAIN-LOGIC.
            STRING "SELECT " X " WHERE a = ?" DELIMITED BY SIZE INTO WS-PREP-SQL END-STRING
            MOVE X TO WS-BIND-1
            PERFORM SQL-EXEC-1
            EXIT PARAGRAPH.
`;
  const d = makeRoot({ 'ok.cob': src });
  const r = run(d);
  assert.equal(r.status, 0, r.out);
});

test('baseline forbids new inline CALL sites', () => {
  const src = `        MAIN-LOGIC.
            MOVE "SELECT 1" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL.
`;
  // Baseline records 0, tree has 1 -> must fail.
  const d = makeRoot({ 'grow.cob': src }, { grow: 0 });
  const r = run(d);
  assert.equal(r.status, 1);
  assert.match(r.out, /baseline/);
});
