// Unit tests for the request-state reset gate (audit C-01).
// Fixture trees keep the gate honest without a COBOL build.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import path from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const GATE = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'check_request_state_reset.mjs');

const WITH_RESET = [
  '       IDENTIFICATION DIVISION.',
  '       PROGRAM-ID. ok.',
  '       PROCEDURE DIVISION.',
  '       MAIN-LOGIC.',
  '           MOVE SPACES TO WS-ERR',
  '           PERFORM ACTION-A.',
  '           GOBACK.',
  '       ACTION-A.',
  '           MOVE "ERROR|X" TO WS-ERR.',
].join('\n');

const WITHOUT_RESET = [
  '       IDENTIFICATION DIVISION.',
  '       PROGRAM-ID. bad.',
  '       PROCEDURE DIVISION.',
  '       MAIN-LOGIC.',
  '           PERFORM ACTION-A.',
  '           GOBACK.',
  '       ACTION-A.',
  '           MOVE "ERROR|X" TO WS-ERR.',
].join('\n');

function makeTree(files) {
  const root = mkdtempSync(path.join(tmpdir(), 'reset-gate-'));
  mkdirSync(path.join(root, 'cobol', 'src'), { recursive: true });
  for (const [name, content] of Object.entries(files)) {
    writeFileSync(path.join(root, 'cobol', 'src', name), content);
  }
  return root;
}

function runGate(root) {
  try {
    const out = execFileSync('node', [GATE, root], { encoding: 'utf8' });
    return { ok: true, out };
  } catch (err) {
    return { ok: false, out: (err.stdout || '') + (err.stderr || '') };
  }
}

test('module with reset passes', () => {
  const root = makeTree({ 'ok_core.cob': WITH_RESET });
  try {
    const r = runGate(root);
    assert.equal(r.ok, true, r.out);
    assert.match(r.out, /OK: 1 modules reset WS-ERR/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('module without reset fails', () => {
  const root = makeTree({ 'bad_core.cob': WITHOUT_RESET });
  try {
    const r = runGate(root);
    assert.equal(r.ok, false, 'expected gate failure');
    assert.match(r.out, /bad_core\.cob: WS-ERR not reset/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('mixed tree reports only the offender', () => {
  const root = makeTree({ 'ok_core.cob': WITH_RESET, 'bad_core.cob': WITHOUT_RESET });
  try {
    const r = runGate(root);
    assert.equal(r.ok, false, 'expected gate failure');
    assert.match(r.out, /bad_core\.cob/);
    assert.doesNotMatch(r.out, /ok_core\.cob: WS-ERR/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
