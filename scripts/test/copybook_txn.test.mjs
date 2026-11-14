// TXN-FINISH pin tests (DRY-06C). No database, no build.
//
// TXN-FINISH centralizes the commit/rollback epilogue: the caller builds
// WS-SUCCESS-MSG (MOVE literal or STRING block), PERFORMs TXN-FINISH (or
// TXN-FINISH-RESULT for the loan_schedule WS-RESULT reporters), which
// commits and moves the message — or rolls back with ERROR|DB_ERROR.
// No new shared working storage: WS-SUCCESS-MSG is declared by each host
// (a 01 in the procedure-division copybook would not compile).
// Modules that keep an inline standard finish are listed in TXN_INLINE_OK
// with a documented reason (post-COMMIT reads, non-DB_ERROR outputs,
// multi-statement epilogues). Everything else must resolve via the copybook.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC = path.join(ROOT, 'cobol', 'src');
const COPY = path.join(ROOT, 'cobol', 'copy');

const modules = readdirSync(SRC)
  .filter((f) => f.endsWith('.cob') && f !== 'main_logic.cob')
  .map((f) => f.replace(/\.cob$/, ''));
const srcOf = (m) => readFileSync(path.join(SRC, `${m}.cob`), 'utf8');

test('common_txn.cpy defines both finish paragraphs, generic', () => {
  const cpy = readFileSync(path.join(COPY, 'common_txn.cpy'), 'utf8');
  assert.match(cpy, /^ {7}TXN-FINISH\.$/m, 'copybook must define TXN-FINISH');
  assert.match(cpy, /^ {7}TXN-FINISH-RESULT\.$/m, 'copybook must define TXN-FINISH-RESULT');
  assert.match(cpy, /CALL "SQL_COMMIT"/, 'finish must own the commit');
  assert.match(cpy, /CALL "SQL_ROLLBACK"/, 'finish must own the rollback');
  assert.match(cpy, /MOVE WS-SUCCESS-MSG TO LS-OUTPUT-BUFFER/, 'finish must move the staged message');
  assert.match(cpy, /MOVE WS-SUCCESS-MSG TO WS-RESULT/, 'result variant must move to WS-RESULT');
  assert.match(cpy, /MOVE "ERROR\|DB_ERROR" TO LS-OUTPUT-BUFFER/, 'finish must own the DB_ERROR output');
  assert.doesNotMatch(cpy, /MOVE "[A-Z0-9_|]+" TO WS-SUCCESS-MSG/, 'copybook must not stage a message');
});

test('every TXN-FINISH host declares WS-SUCCESS-MSG and COPYs common_txn', () => {
  let sites = 0;
  for (const m of modules) {
    const src = srcOf(m);
    const performs = [...src.matchAll(/^\s*PERFORM (TXN-FINISH(?:-RESULT)?)\s*$/gm)];
    if (!performs.length) continue;
    sites += performs.length;
    assert.match(src, /COPY "common_txn\.cpy"/, `${m}: missing common_txn COPY`);
    assert.match(src, /^\s+01\s+WS-SUCCESS-MSG\s+PIC X\(16384\)/m, `${m}: missing WS-SUCCESS-MSG declaration`);
  }
  assert.ok(sites >= 150, `expected 150+ converted sites, got ${sites}`);
});

test('no module defines TXN-FINISH inline', () => {
  for (const m of modules) {
    assert.doesNotMatch(srcOf(m), /^\s{7,8}TXN-FINISH(-RESULT)?\.\s*$/m, `${m}: inline TXN-FINISH`);
  }
});

test('WS-SUCCESS-MSG never splits an 88 group', () => {
  // Regression pin (DRY-06C): the shared-message declaration must not be
  // inserted between an 01 and its 88 children — that silently reparents
  // the 88s and breaks every SET/IF on them (caught by collection DB tests).
  for (const m of modules) {
    const lines = srcOf(m).split('\n');
    lines.forEach((line, idx) => {
      if (!/^\s+01\s+WS-SUCCESS-MSG\s/.test(line)) return;
      for (let j = idx + 1; j < lines.length; j += 1) {
        const l = lines[j];
        if (!l.trim()) continue;
        if (/^\s+88\s/.test(l)) {
          assert.fail(`${m}:${idx + 1}: 88 level follows WS-SUCCESS-MSG (split 88 group)`);
        }
        break;
      }
    });
  }
});
