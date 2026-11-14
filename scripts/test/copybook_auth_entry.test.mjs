// Auth entry copybook pins (DRY-03). No database, no build.
//
// auth_entry.cpy holds the shared auth entry trim/validate (TRIM-PARAM1..6,
// VALIDATE-ALL/VALIDATE-INPUT, NL/CR charset, 4-param WS-CHECK shape) used
// by all 6 auth modules. auth_session_core reuses it instead of its own
// ENTRY-TRIM/ENTRY-VALIDATE (same statement-for-statement semantics).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC = path.join(ROOT, 'cobol', 'src');
const COPY = path.join(ROOT, 'cobol', 'copy');

const ENTRY_HOSTS = [
  'auth_core',
  'auth_mfa_core',
  'auth_ops_core',
  'auth_recovery_core',
  'auth_review_core',
  'auth_session_core',
];

const srcOf = (m) => readFileSync(path.join(SRC, `${m}.cob`), 'utf8');

test('auth_entry.cpy defines the shared trim/validate pair', () => {
  const cpy = readFileSync(path.join(COPY, 'auth_entry.cpy'), 'utf8');
  for (const name of ['TRIM-PARAM1', 'TRIM-PARAM2', 'TRIM-PARAM3', 'TRIM-PARAM4', 'TRIM-PARAM5', 'TRIM-PARAM6']) {
    assert.match(cpy, new RegExp(`^\\s{7,8}${name}\\.`, 'm'), `copybook must define ${name}`);
  }
  assert.match(cpy, /^\s{7,8}VALIDATE-ALL\./m);
  assert.match(cpy, /^\s{7,8}VALIDATE-INPUT\./m);
  assert.match(cpy, /F-NL/, 'auth NL/CR charset must be preserved');
  assert.match(cpy, /F-CR/, 'auth NL/CR charset must be preserved');
});

test('all 6 auth modules COPY auth_entry.cpy, none defines entry paragraphs inline', () => {
  for (const m of ENTRY_HOSTS) {
    const src = srcOf(m);
    assert.match(src, /COPY "auth_entry\.cpy"/, `${m}: missing auth_entry COPY`);
    for (const name of ['TRIM-PARAM1', 'TRIM-PARAM2', 'TRIM-PARAM3', 'TRIM-PARAM4', 'TRIM-PARAM5', 'TRIM-PARAM6']) {
      assert.doesNotMatch(src, new RegExp(`^\\s{7,8}${name}\\.`, 'm'), `${m}: inline ${name}`);
    }
    assert.doesNotMatch(src, /^\s{7,8}VALIDATE-ALL\./m, `${m}: inline VALIDATE-ALL`);
    assert.doesNotMatch(src, /^\s{7,8}VALIDATE-INPUT\./m, `${m}: inline VALIDATE-INPUT`);
  }
});

test('auth_session uses shared entry paragraphs, not its own', () => {
  const src = srcOf('auth_session_core');
  assert.doesNotMatch(src, /^\s{7,8}ENTRY-TRIM\./m, 'ENTRY-TRIM must be gone');
  assert.doesNotMatch(src, /^\s{7,8}ENTRY-VALIDATE\./m, 'ENTRY-VALIDATE must be gone');
  assert.ok(/PERFORM TRIM-PARAM1/.test(src), 'session must PERFORM TRIM-PARAM1..6');
  assert.ok(/PERFORM VALIDATE-ALL/.test(src), 'session must PERFORM VALIDATE-ALL');
});

test('no unreachable password copybook remains in the four split modules', () => {
  for (const m of ['auth_mfa_core', 'auth_ops_core', 'auth_recovery_core', 'auth_review_core']) {
    const src = srcOf(m);
    assert.doesNotMatch(src, /COPY "auth_password_logic\.cpy"/, `${m}: dead password logic COPY`);
    assert.doesNotMatch(src, /COPY "auth_password_helpers\.cpy"/, `${m}: dead password helpers COPY`);
  }
});
