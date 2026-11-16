// Unit tests for the module size ratchet (audit A-08).
// The gate itself scans the real tree; these tests pin the limit logic
// with fixture trees so a broken gate fails fast without a build.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import path from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const GATE = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'check_module_size.mjs');

function makeTree(files) {
  const root = mkdtempSync(path.join(tmpdir(), 'size-gate-'));
  for (const [rel, content] of Object.entries(files)) {
    const full = path.join(root, rel);
    mkdirSync(path.dirname(full), { recursive: true });
    writeFileSync(full, content);
  }
  // Gate globs fixed subtrees; create the empties it expects.
  for (const d of ['cobol/src', 'middleware/src', 'middleware/test', 'scripts']) {
    mkdirSync(path.join(root, d), { recursive: true });
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

const SMALL_COB = '       IDENTIFICATION DIVISION.\n       PROGRAM-ID. tiny.\n\n       PROCEDURE DIVISION.\n       MAIN-LOGIC.\n           MOVE SPACES TO WS-ERR\n           GOBACK.\n';

test('small tree passes', () => {
  const root = makeTree({ 'cobol/src/tiny_core.cob': SMALL_COB });
  try {
    const r = runGate(root);
    assert.equal(r.ok, true, r.out);
    assert.match(r.out, /OK: module size ratchet holds/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('oversize paragraph fails', () => {
  const big = `${'       IDENTIFICATION DIVISION.\n'}       PROGRAM-ID. big.\n\n       PROCEDURE DIVISION.\n       BIG-PARA.\n${'           MOVE 1 TO WS-X\n'.repeat(700)}           GOBACK.\n`;
  const root = makeTree({ 'cobol/src/big_core.cob': big });
  try {
    const r = runGate(root);
    assert.equal(r.ok, false, 'expected gate failure');
    assert.match(r.out, /BIG-PARA/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('oversize gateway file fails', () => {
  const big = `${'// line\n'.repeat(501)}`;
  const root = makeTree({ 'middleware/src/big.js': big });
  try {
    const r = runGate(root);
    assert.equal(r.ok, false, 'expected gate failure');
    assert.match(r.out, /big\.js/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
