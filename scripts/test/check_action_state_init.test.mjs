// Unit tests for the cross-action state gate (numeric-hardening follow-up).
// A field written only by ACTION-ONE but read by ACTION-TWO used to work by
// accident via --serve WORKING-STORAGE persistence (real case: statement_core
// WS-RUN-ID written by ACTION-RUN-START, read by ACTION-RUN-GENERATE).
// Fixture trees keep the gate honest without a COBOL build.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import path from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const GATE = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'check_action_state_init.mjs');

const SHARED_HEADER = [
  '       IDENTIFICATION DIVISION.',
  '       PROGRAM-ID. mod_core.',
  '       DATA DIVISION.',
  '       WORKING-STORAGE SECTION.',
  '       01  WS-FOO                PIC X(10) VALUE SPACES.',
  '       PROCEDURE DIVISION.',
].join('\n');

const FRESH_STATE = [
  SHARED_HEADER,
  '       MAIN-LOGIC.',
  '           MOVE SPACES TO WS-FOO',
  '           EVALUATE TRUE',
  '               WHEN LS-CMD-ACTION(1:3) = "AAA"',
  '                   PERFORM ACTION-ONE',
  '               WHEN LS-CMD-ACTION(1:3) = "BBB"',
  '                   PERFORM ACTION-TWO',
  '           END-EVALUATE.',
  '           GOBACK.',
  '       ACTION-ONE.',
  '           MOVE "1" TO WS-FOO',
  '           EXIT PARAGRAPH.',
  '       ACTION-TWO.',
  '           DISPLAY WS-FOO',
  '           EXIT PARAGRAPH.',
  '       END PROGRAM mod_core.',
].join('\n');

const STALE_STATE = [
  SHARED_HEADER,
  '       MAIN-LOGIC.',
  '           EVALUATE TRUE',
  '               WHEN LS-CMD-ACTION(1:3) = "AAA"',
  '                   PERFORM ACTION-ONE',
  '               WHEN LS-CMD-ACTION(1:3) = "BBB"',
  '                   PERFORM ACTION-TWO',
  '           END-EVALUATE.',
  '           GOBACK.',
  '       ACTION-ONE.',
  '           MOVE "1" TO WS-FOO',
  '           EXIT PARAGRAPH.',
  '       ACTION-TWO.',
  '           DISPLAY WS-FOO',
  '           EXIT PARAGRAPH.',
  '       END PROGRAM mod_core.',
].join('\n');

function makeTree(files) {
  const root = mkdtempSync(path.join(tmpdir(), 'state-gate-'));
  mkdirSync(path.join(root, 'cobol', 'src'), { recursive: true });
  mkdirSync(path.join(root, 'cobol', 'copy'), { recursive: true });
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

test('entry-reset state passes', () => {
  const root = makeTree({ 'mod_core.cob': FRESH_STATE });
  try {
    const r = runGate(root);
    assert.equal(r.ok, true, r.out);
    assert.match(r.out, /OK: 2 ACTION paragraphs/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('stale cross-action read fails', () => {
  const root = makeTree({ 'mod_core.cob': STALE_STATE });
  try {
    const r = runGate(root);
    assert.equal(r.ok, false, 'gate must fail without entry reset');
    assert.match(r.out, /WS-FOO read in ACTION-TWO, only written in ACTION-ONE/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
