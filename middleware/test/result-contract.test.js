// Result-protocol contract tests (arch9 WP-12): money-path actions through
// the real HTTP stack with a stubbed COBOL binary. Proves the strict parser
// is wired end to end: unknown/empty COBOL output becomes a 500 with a
// registered code, never a 200 success; valid output keeps its shape.
import { test, before } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, chmod } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import request from 'supertest';

const dir = await mkdtemp(path.join(tmpdir(), 'cobol-contract-'));
const stub = path.join(dir, 'contract-binary');
await writeFile(
  stub,
  [
    '#!/bin/sh',
    'line=$(cat input.txt 2>/dev/null || true)',
    'action=$(printf "%s" "$line" | cut -d"|" -f1)',
    'case "$action" in',
    '  TRANSFER) printf "%s" "${TRANSFER_RESPONSE-SUCCESS|TRANSFER_OK}" > output.txt ;;',
    '  CHECK_BALANCE) printf "%s" "${BALANCE_RESPONSE-SUCCESS|BALANCES|USD:100.00:90.00:ACTIVE}" > output.txt ;;',
    '  *) printf "SUCCESS|TEST_OK" > output.txt ;;',
    'esac',
  ].join('\n') + '\n',
);
await chmod(stub, 0o755);
process.env.COBOL_BIN = stub;

const { buildApp } = await import('../src/app.js');
const { signToken } = await import('../src/auth.js');

const tokenStore = {
  async isActive() {
    return true;
  },
  async revoke() {},
};

let app;
before(() => {
  app = buildApp({ tokenStore });
});

const bearer = () => `Bearer ${signToken({ email: 'contract@test.com', ver: 1, jti: 'contract-jti' })}`;

test('CHECK_BALANCE keeps its shape on valid output', async () => {
  process.env.BALANCE_RESPONSE = 'SUCCESS|BALANCES|USD:100.00:90.00:ACTIVE';
  const res = await request(app)
    .get('/wallet/balance')
    .query({ email: 'contract@test.com' })
    .set('Authorization', bearer());
  assert.equal(res.status, 200);
  assert.deepEqual(res.body.balances, [{ currency: 'USD', balance: '100.00', available: '90.00', status: 'ACTIVE' }]);
});

test('TRANSFER with unknown COBOL output is a 500 INVALID_RESPONSE, never success', async () => {
  process.env.TRANSFER_RESPONSE = 'garbage-no-pipe';
  const res = await request(app)
    .post('/wallet/transfer')
    .set('Authorization', bearer())
    .send({ to: 'other@test.com', amount: '10.00', idempotencyKey: 'ctr-1' });
  assert.equal(res.status, 500);
  assert.equal(res.body.error, 'INVALID_RESPONSE');
});

test('TRANSFER with empty COBOL output is a 500 EMPTY_RESPONSE', async () => {
  process.env.TRANSFER_RESPONSE = '';
  const res = await request(app)
    .post('/wallet/transfer')
    .set('Authorization', bearer())
    .send({ to: 'other@test.com', amount: '10.00', idempotencyKey: 'ctr-2' });
  assert.equal(res.status, 500);
  assert.equal(res.body.error, 'EMPTY_RESPONSE');
});

test('TRANSFER maps a business error to its documented HTTP status', async () => {
  process.env.TRANSFER_RESPONSE = 'ERROR|INSUFFICIENT_FUNDS|short';
  const res = await request(app)
    .post('/wallet/transfer')
    .set('Authorization', bearer())
    .send({ to: 'other@test.com', amount: '10.00', idempotencyKey: 'ctr-3' });
  assert.equal(res.status, 409);
  assert.equal(res.body.error, 'INSUFFICIENT_FUNDS');
  assert.deepEqual(res.body.detail, ['short']);
});

test('LOAN_DISBURSE success keeps its shape', async () => {
  const res = await request(app).post('/loans/9/disburse').set('Authorization', bearer()).send({});
  assert.equal(res.status, 200);
  assert.deepEqual(res.body.data[0], 'TEST_OK');
});
