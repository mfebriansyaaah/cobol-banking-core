// Envelope v1 unit tests (arch9 WP-14): shape pins for ok/fail/isV1.
// No database, no build.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ok, fail, isV1 } from '../src/envelope.js';

test('ok wraps payload with empty meta and null error', () => {
  assert.deepEqual(ok({ a: 1 }), { data: { a: 1 }, meta: {}, error: null });
  assert.deepEqual(ok([1], { requestId: 'r' }), { data: [1], meta: { requestId: 'r' }, error: null });
});

test('fail carries code and detail with null data', () => {
  assert.deepEqual(fail('X', 'd', { requestId: 'r' }), {
    data: null,
    meta: { requestId: 'r' },
    error: { code: 'X', detail: 'd' },
  });
  assert.deepEqual(fail('X'), { data: null, meta: {}, error: { code: 'X', detail: null } });
});

test('isV1 detects the alias mount and the raw path', () => {
  assert.equal(isV1({ baseUrl: '/v1', path: '/users' }), true);
  assert.equal(isV1({ baseUrl: '/v1/auth', path: '/login' }), true);
  assert.equal(isV1({ baseUrl: '', path: '/v1/users' }), true);
  assert.equal(isV1({ baseUrl: '', path: '/users' }), false);
  assert.equal(isV1({}), false);
  assert.equal(isV1(null), false);
});
