import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parse, toHttp } from '../src/result.js';

test('success maps to 200 with data fields', () => {
  assert.deepEqual(toHttp('SUCCESS|LOGIN_OK'), { status: 200, body: { data: ['LOGIN_OK'] } });
});

test('not-found error maps to 404', () => {
  assert.equal(toHttp('ERROR|ACCOUNT_NOT_FOUND').status, 404);
});

test('locked account maps to 423', () => {
  const r = toHttp('ERROR|ACCOUNT_LOCKED');
  assert.equal(r.status, 423);
  assert.equal(r.body.error, 'ACCOUNT_LOCKED');
});

test('a bare value (no prefix) is treated as success data', () => {
  assert.deepEqual(toHttp('1|sender@test.com'), { status: 200, body: { data: ['1', 'sender@test.com'] } });
  assert.deepEqual(toHttp('1000.00'), { status: 200, body: { data: ['1000.00'] } });
});

test('reconcile mismatch maps to 409 with the offending account(s)', () => {
  const r = toHttp('ERROR|MISMATCH|2|5.00|0.00');
  assert.equal(r.status, 409);
  assert.equal(r.body.error, 'MISMATCH');
  assert.deepEqual(r.body.detail, ['2', '5.00', '0.00']);
});

test('session and token errors map to 401', () => {
  for (const code of ['SESSION_NOT_FOUND', 'SESSION_EXPIRED', 'SESSION_REUSED', 'TOKEN_REVOKED']) {
    assert.equal(toHttp(`ERROR|${code}`).status, 401, code);
  }
});

test('internal failures map to 500', () => {
  for (const code of ['SESSION_CHECK_FAILED', 'SESSION_REVOKE_FAILED', 'TOKEN_REVOKE_FAILED', 'DB_CONN_FAILED', 'PREPARE_FAILED', 'EXEC_FAILED', 'NO_TRANSACTION']) {
    assert.equal(toHttp(`ERROR|${code}`).status, 500, code);
  }
});
