// Auth session split pins (maint-08). No database, no build.
//
// auth_session_core.cob owns the session/token paragraphs relocated from
// auth_core (STORE/REVOKE/CONSUME/CHECK_TOKEN/REVOKE_TOKEN/LIST/
// REVOKE_USER/REVOKE_ALL/GET_TOKEN_VERSION plus the ENFORCE/IDLE/FAMILY
// and audit/trim helpers they use). auth_core keeps dispatch, the auth
// guards (ALLOW-READ/ALLOW-MANAGE-SESSION stay owner-side and run before
// the CALL), and the single transaction for REVOKE_ALL_SESSIONS (JOIN
// pattern, ADR-0010). Universal invariants:
//   - the session module opens no transaction (0 BEGIN/COMMIT/ROLLBACK);
//   - it never calls back into auth_core (acyclic: auth -> session);
//   - auth_core no longer holds the moved paragraphs;
//   - the call graph records the new edge (session calls nothing).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC = path.join(ROOT, 'cobol', 'src');
const srcOf = (module) => readFileSync(path.join(SRC, `${module}.cob`), 'utf8');

const MOVED = [
  'STORE-SESSION-LOGIC',
  'REVOKE-SESSION-LOGIC',
  'ENFORCE-IDLE-TIMEOUT',
  'CONSUME-SESSION-LOGIC',
  'ENFORCE-FAMILY-LIMITS',
  'GET-TOKEN-VERSION-LOGIC',
  'CHECK-TOKEN-LOGIC',
  'REVOKE-ACCESS-TOKEN-LOGIC',
  'LIST-SESSIONS-LOGIC',
  'REVOKE-USER-SESSION-LOGIC',
  'AUDIT-SESSION-REVOKED',
  'REVOKE-ALL-SESSIONS-LOGIC',
];

// Duplicated utility (like account/auth_mfa/auth_ops carry their own):
// the session module defines its own copy, auth_core keeps its own for
// auth_password_helpers.cpy.
const CALLEE_UTIL = ['TRIM-RESULT-LEN'];

test('auth_session_core defines the session paragraphs', () => {
  const src = srcOf('auth_session_core');
  for (const name of [...MOVED, ...CALLEE_UTIL]) {
    assert.match(src, new RegExp(`^ {8}${name}\\.$`, 'm'), `session module must define ${name}`);
  }
});

test('auth_session_core opens no transaction and never calls back', () => {
  const src = srcOf('auth_session_core');
  assert.doesNotMatch(src, /CALL "SQL_BEGIN"/, 'caller owns the single transaction');
  assert.doesNotMatch(src, /CALL "SQL_COMMIT"/, 'caller owns the single transaction');
  assert.doesNotMatch(src, /CALL "SQL_ROLLBACK"/, 'caller owns the single transaction');
  assert.doesNotMatch(src, /CALL "auth_core"/, 'no callback into the owner (acyclic)');
});

test('auth_core delegates session work to the session module', () => {
  const src = srcOf('auth_core');
  assert.match(src, /CALL "auth_session_core"/, 'auth_core must CALL the session module');
  for (const name of MOVED) {
    assert.doesNotMatch(src, new RegExp(`^ {8}${name}\\.$`, 'm'), `moved paragraph ${name} must be gone`);
  }
  // Guards stay owner-side and run before the CALL.
  assert.match(src, /^ {8}ALLOW-READ\.$/m, 'ALLOW-READ stays in auth_core');
  assert.match(src, /^ {8}ALLOW-MANAGE-SESSION\.$/m, 'ALLOW-MANAGE-SESSION stays in auth_core');
});

test('call graph records the new session edge', () => {
  const doc = JSON.parse(readFileSync(path.join(ROOT, 'manifest', 'cobol_calls.json'), 'utf8'));
  const keys = new Set(doc.edges.map((e) => `${e.from} -> ${e.to}`));
  assert.ok(keys.has('auth_core -> auth_session_core'), 'registry must list the new edge');
});
