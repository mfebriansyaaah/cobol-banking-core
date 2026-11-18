// Unit tests for scripts/check_commit_results.mjs.
// No database, no build. Verifies the gate catches bare CALLs.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const GATE = path.join(ROOT, 'scripts', 'check_commit_results.mjs');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

function makeTree({ srcBare = false, missingCopy = false } = {}) {
  const d = mkdtempSync(path.join(tmpdir(), 'commitres-'));
  dirs.push(d);
  mkdirSync(path.join(d, 'cobol', 'src'), { recursive: true });
  mkdirSync(path.join(d, 'cobol', 'copy'), { recursive: true });
  const commitChecked = `       COMMIT-CHECKED.\n           CALL "SQL_COMMIT" END-CALL\n           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL\n           IF WS-RESULT NOT = "SUCCESS|COMMIT"\n               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER\n           END-IF.\n           EXIT PARAGRAPH.\n`;
  writeFileSync(path.join(d, 'cobol', 'copy', 'common_commit.cpy'), commitChecked);
  writeFileSync(
    path.join(d, 'cobol', 'copy', 'common_txn.cpy'),
    `       TXN-FINISH.\n           CALL "SQL_COMMIT" END-CALL\n           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL\n           IF WS-RESULT NOT = "SUCCESS|COMMIT"\n               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER\n           END-IF.\n           EXIT PARAGRAPH.\n`,
  );
  const body = srcBare
    ? '       PROCEDURE DIVISION.\n           CALL "SQL_COMMIT" END-CALL\n'
    : missingCopy
      ? '       PROCEDURE DIVISION.\n           PERFORM COMMIT-CHECKED\n'
      : '       PROCEDURE DIVISION.\n           COPY "common_commit.cpy".\n           PERFORM COMMIT-CHECKED\n';
  writeFileSync(path.join(d, 'cobol', 'src', 'demo_core.cob'), body);
  return d;
}

function runGate(dir) {
  try {
    execFileSync(process.execPath, [GATE, dir], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
    return { ok: true, out: '' };
  } catch (e) {
    return { ok: false, out: String((e && e.stdout) || '') + String((e && e.stderr) || '') };
  }
}

test('clean tree passes', () => {
  const r = runGate(makeTree());
  assert.equal(r.ok, true);
});

test('bare CALL in src fails', () => {
  const r = runGate(makeTree({ srcBare: true }));
  assert.equal(r.ok, false);
  assert.match(r.out, /bare CALL/);
});

test('missing COPY fails', () => {
  const r = runGate(makeTree({ missingCopy: true }));
  assert.equal(r.ok, false);
  assert.match(r.out, /without COPY/);
});
