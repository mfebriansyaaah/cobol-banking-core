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

test('malformed line is treated as a server error', () => {
  assert.deepEqual(parse('garbage').code, 'MALFORMED');
  assert.equal(toHttp('garbage').status, 500);
});
