// Unit tests for scripts/check_affected_rows.mjs.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const GATE = path.join(ROOT, 'scripts', 'check_affected_rows.mjs');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

function makeTree({ legacy = false } = {}) {
  const d = mkdtempSync(path.join(tmpdir(), 'affrows-'));
  dirs.push(d);
  mkdirSync(path.join(d, 'cobol', 'src'), { recursive: true });
  const body = legacy
    ? '       PROCEDURE DIVISION.\n           IF WS-RESULT = "0 rows affected"\n               CONTINUE\n           END-IF.\n'
    : '       PROCEDURE DIVISION.\n           IF WS-RESULT = "SUCCESS|AFFECTED_0"\n               CONTINUE\n           END-IF.\n';
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

test('legacy literal fails', () => {
  const r = runGate(makeTree({ legacy: true }));
  assert.equal(r.ok, false);
  assert.match(r.out, /0 rows affected/);
});
