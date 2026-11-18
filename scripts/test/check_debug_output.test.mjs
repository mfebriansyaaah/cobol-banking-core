// Unit tests for scripts/check_debug_output.mjs.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const GATE = path.join(ROOT, 'scripts', 'check_debug_output.mjs');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

function makeTree({ debug = false } = {}) {
  const d = mkdtempSync(path.join(tmpdir(), 'dbgout-'));
  dirs.push(d);
  mkdirSync(path.join(d, 'cobol', 'src'), { recursive: true });
  mkdirSync(path.join(d, 'cobol', 'copy'), { recursive: true });
  const body = debug
    ? '       PROCEDURE DIVISION.\n           MOVE "DEBUG|STEP_OK" TO LS-OUTPUT-BUFFER\n'
    : '       PROCEDURE DIVISION.\n           MOVE "SUCCESS|OK" TO LS-OUTPUT-BUFFER\n';
  writeFileSync(path.join(d, 'cobol', 'src', 'demo_core.cob'), body);
  writeFileSync(path.join(d, 'cobol', 'copy', 'demo.cpy'), '      *> helper\n');
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

test('debug literal fails', () => {
  const r = runGate(makeTree({ debug: true }));
  assert.equal(r.ok, false);
  assert.match(r.out, /DEBUG\|/);
});
