// Unit tests for scripts/check_test_registration.mjs (maint-02).
// No database, no build.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { checkRegistration, listTestFiles } from '../check_test_registration.mjs';
import { GROUPS } from '../../middleware/scripts/test-files.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

test('unregistered file is reported', () => {
  const missing = checkRegistration(['test/a.test.js', 'test/b.test.js'], { g: ['test/a.test.js'] });
  assert.deepEqual(missing, ['test/b.test.js']);
});

test('fully registered set passes', () => {
  assert.deepEqual(checkRegistration(['test/a.test.js'], { g: ['test/a.test.js'], h: ['test/a.test.js'] }), []);
});

test('groups compose without loss (fast/full/db supersets hold)', () => {
  const { unit, fast, full, db, gateway, endpoints } = GROUPS;
  for (const f of unit) assert.ok(fast.includes(f) && full.includes(f), `${f} in fast+full`);
  for (const f of fast) assert.ok(full.includes(f), `${f} in full`);
  for (const f of gateway) assert.ok(db.includes(f) && full.includes(f), `${f} in db+full`);
  for (const f of endpoints) assert.ok(gateway.includes(f), `${f} in gateway`);
  assert.equal(new Set(full).size, full.length, 'no duplicates in full');
});

test('db group keeps the exact serial test:db order', () => {
  const want = [
    'test/auth-session.test.js',
    'test/ipc_contract.test.js',
    'test/ipc_contract_pool.test.js',
    'test/observability.test.js',
    'test/pool.test.js',
    'test/gateway.test.js',
    'test/endpoints.test.js',
  ];
  assert.deepEqual(GROUPS.db, want);
});

test('gate holds on the real tree', () => {
  const out = execFileSync('node', [path.join(ROOT, 'scripts', 'check_test_registration.mjs'), ROOT], {
    encoding: 'utf8',
  });
  assert.match(out, /OK: all \d+ gateway test files registered/);
  const files = listTestFiles(path.join(ROOT, 'middleware', 'test'));
  assert.ok(files.length >= 30, `expected 30+ test files, got ${files.length}`);
});
