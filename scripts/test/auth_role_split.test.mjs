// Auth role/step-up extraction pins (maint-15C). No database, no build.
//
// Five authorization paragraphs moved out of auth_core.cob:
//   - GUARD-LAST-ADMIN-ROLE was duplicated byte-for-byte in auth_core and
//     auth_recovery_core; it now lives once in auth_last_admin.cpy, which
//     both hosts COPY.
//   - CHECK-ROLE-LOGIC / CHANGE-ROLE-LOGIC / VERIFY-REAUTH-LOGIC /
//     STEP-UP-REQUIRED-LOGIC are auth_core-only and now live in
//     auth_role_logic.cpy (same working storage, same audit helpers).
// These pins fail if a host regrows an inline copy, an include goes
// missing, a copybook hardcodes module-specific fields, or a second
// consumer appears without its own interface check.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC_DIR = path.join(ROOT, 'cobol', 'src');
const COPY_DIR = path.join(ROOT, 'cobol', 'copy');

const SHARED = ['GUARD-LAST-ADMIN-ROLE'];
const AUTH_ONLY = ['CHECK-ROLE-LOGIC', 'CHANGE-ROLE-LOGIC', 'VERIFY-REAUTH-LOGIC', 'STEP-UP-REQUIRED-LOGIC'];

const modules = readdirSync(SRC_DIR)
  .filter((f) => f.endsWith('.cob') && f !== 'main_logic.cob')
  .map((f) => f.replace(/\.cob$/, ''))
  .sort();
const srcOf = (module) => readFileSync(path.join(SRC_DIR, `${module}.cob`), 'utf8');
const copyOf = (file) => readFileSync(path.join(COPY_DIR, file), 'utf8');
const inlineDefines = (src, name) => new RegExp(`^ {7,8}${name}\\.$`, 'm').test(src);

test('auth_last_admin.cpy defines the shared guard generically', () => {
  const cpy = copyOf('auth_last_admin.cpy');
  assert.match(cpy, /^ {7,8}GUARD-LAST-ADMIN-ROLE\.$/m, 'copybook must define GUARD-LAST-ADMIN-ROLE');
  // Interface the shared paragraph relies on (both hosts declare them).
  for (const field of ['WS-ALLOWED', 'WS-PARAM1-TRIMMED', 'WS-PARAM2-TRIMMED', 'WS-P2-LEN', 'LOOKUP-USER-ROLE']) {
    assert.match(cpy, new RegExp(`\\b${field}\\b`), `copybook must use the documented interface field ${field}`);
  }
  assert.doesNotMatch(cpy, /MOVE\s+"[A-Z0-9_]+" TO\s+WS-DENIED-TARGET/, 'copybook must not hardcode a module target');
});

test('auth_role_logic.cpy defines the four auth-only paragraphs', () => {
  const cpy = copyOf('auth_role_logic.cpy');
  for (const name of AUTH_ONLY) {
    assert.match(cpy, new RegExp(`^ {7,8}${name}\\.$`, 'm'), `copybook must define ${name}`);
  }
});

test('auth_core COPYs both files and keeps no inline copy', () => {
  const src = srcOf('auth_core');
  assert.match(src, /COPY "auth_last_admin\.cpy"/, 'auth_core must COPY auth_last_admin.cpy');
  assert.match(src, /COPY "auth_role_logic\.cpy"/, 'auth_core must COPY auth_role_logic.cpy');
  for (const name of [...SHARED, ...AUTH_ONLY]) {
    assert.ok(!inlineDefines(src, name), `auth_core: inline ${name} must be gone`);
  }
});

test('auth_recovery_core shares the guard and does not copy auth-only logic', () => {
  const src = srcOf('auth_recovery_core');
  assert.match(src, /COPY "auth_last_admin\.cpy"/, 'auth_recovery_core must COPY auth_last_admin.cpy');
  assert.ok(!inlineDefines(src, 'GUARD-LAST-ADMIN-ROLE'), 'auth_recovery_core: inline guard must be gone');
  // The four auth-only paragraphs depend on auth_core's working storage;
  // a second consumer needs its own interface review before copying them.
  assert.doesNotMatch(src, /COPY "auth_role_logic\.cpy"/, 'auth_recovery_core must not copy auth_role_logic.cpy');
});

test('no module defines the extracted paragraphs inline', () => {
  const offenders = [];
  for (const module of modules) {
    const src = srcOf(module);
    for (const name of [...SHARED, ...AUTH_ONLY]) {
      if (inlineDefines(src, name)) offenders.push(`${module}:${name}`);
    }
  }
  assert.deepEqual(offenders, []);
});
