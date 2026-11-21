// Pagination + envelope contract (arch9 WP-14): every route serves an
// enveloped twin under /v1, and every route declaring `pagination` returns
// paged data with meta on v1. Legacy paths keep their exact shape.
// Real HTTP stack with a stubbed COBOL binary; no database, no network.
import { test, before } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, chmod } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import request from 'supertest';

const dir = await mkdtemp(path.join(tmpdir(), 'cobol-pagination-'));
const stub = path.join(dir, 'pagination-binary');
const rows = {
  LIST_USERS: 'SUCCESS|LIST_DONE|2|7:a@b.c:Ada:USER:VERIFIED;8:d@e.f:Bo:USER:VERIFIED',
  STATEMENT: 'SUCCESS|STATEMENT|100.00|90.00|USD|2|1:2026-01-01:2026-01-01:R1:TRANSFER:DEBIT:10.00:90.00:0:note',
  LIST_DISPUTES: 'SUCCESS|DISPUTES|1|9:o@t.co:Subj:OPEN:2026-02-01:0:2026-01-01',
  LIST_ACCESS_REVIEWS: 'SUCCESS|REVIEWS|1|1:2026-01-01:2026-01-31:OPEN:boss:5::',
  ACC_LIST: 'SUCCESS|ACC_LIST|1:R-1:ACTIVE:10.00:0.00:Ann',
  LOAN_LIST: 'SUCCESS|LOAN_LIST|4:L-9:ACTIVE:5000:1000:Bob',
  DEP_LIST: 'SUCCESS|DEPOSITS|2:d@t.co:1000:USD:12:ACTIVE:50.00',
  CARD_LIST: 'SUCCESS|CARDS|3:C-1:c@t.co:DEBIT:ACTIVE:5000:4000:1000:****1',
  PAY_POLICY_LIST: 'SUCCESS|PAY_POLICIES|3 |USD:1000:500:2:50:10:1',
  IMP_BATCH_LIST: 'SUCCESS|IMP_BATCHES|2 |9:B-1:core:LEDGER:POSTED:10:9:1:9',
  RPT_TEMPLATE_LIST: 'SUCCESS|RPT_TEMPLATES|1 |5:T-1:Monthly:TRIAL_BALANCE:CSV:1:Month end',
};
await writeFile(
  stub,
  [
    '#!/bin/sh',
    'line=$(cat input.txt 2>/dev/null || true)',
    'action=$(printf "%s" "$line" | cut -d"|" -f1)',
    'case "$action" in',
    ...Object.entries(rows).map(([a]) => `  ${a}) printf "%s" "$${a}_RESPONSE" > output.txt ;;`),
    '  PING) printf "SUCCESS|PONG" > output.txt ;;',
    '  *) printf "SUCCESS|TEST_OK" > output.txt ;;',
    'esac',
  ].join('\n') + '\n',
);
await chmod(stub, 0o755);
for (const [action, out] of Object.entries(rows)) process.env[`${action}_RESPONSE`] = out;
process.env.COBOL_BIN = stub;

const { buildApp } = await import('../src/app.js');
const { signToken } = await import('../src/auth.js');
const { ALL_ROUTES } = await import('../src/routes/index.js');

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

const bearer = () => `Bearer ${signToken({ email: 'page@t.co', ver: 1, jti: 'page-jti' })}`;
const paged = ALL_ROUTES.filter((r) => r.pagination && !r.custom);

test('T-14.1: /v1/health is enveloped, legacy /health is untouched', async () => {
  const legacy = await request(app).get('/health');
  assert.ok(!('error' in legacy.body) || legacy.body.status, 'legacy keeps its shape');
  assert.equal('meta' in legacy.body, false);
  const v1 = await request(app).get('/v1/health');
  assert.equal(v1.status, legacy.status);
  assert.equal(v1.body.error, null);
  assert.equal(typeof v1.body.meta.requestId, 'string');
  assert.ok(v1.body.data && typeof v1.body.data === 'object', 'payload nested under data');
});

test('T-14.1: v1 errors are enveloped, legacy errors are untouched', async () => {
  const legacy = await request(app).get('/users');
  assert.equal(legacy.status, 401);
  assert.deepEqual(legacy.body, { error: 'MISSING_TOKEN' });
  const v1 = await request(app).get('/v1/users');
  assert.equal(v1.status, 401);
  assert.equal(v1.body.data, null);
  assert.deepEqual(v1.body.error, { code: 'MISSING_TOKEN', detail: null });
  assert.equal(typeof v1.body.meta.requestId, 'string');
});

test('T-14.2: every paginated route returns data+meta on v1', async (t) => {
  assert.ok(paged.length >= 11, `expected 11+ paginated routes, got ${paged.length}`);
  for (const route of paged) {
    await t.test(`${route.method.toUpperCase()} ${route.path} → ${route.action}`, async () => {
      const query = { limit: '5', offset: '2' };
      // STATEMENT keys its ledger read off explicit email+currency, not the token.
      if (route.action === 'STATEMENT') {
        query.email = 'page@t.co';
        query.currency = 'USD';
      }
      const res = await request(app).get(`/v1${route.path}`).set('Authorization', bearer()).query(query);
      assert.equal(res.status, 200, `${route.action}: ${JSON.stringify(res.body).slice(0, 200)}`);
      assert.equal(res.body.error, null);
      assert.ok(Array.isArray(res.body.data), `${route.action}: data must be an array`);
      assert.equal(typeof res.body.meta.requestId, 'string');
      assert.equal(typeof res.body.meta.limit, 'number');
      assert.equal(typeof res.body.meta.offset, 'number');
      assert.equal(res.body.meta.limit, 5);
      assert.equal(res.body.meta.offset, 2);
      assert.ok(res.body.meta.total === null || typeof res.body.meta.total === 'number');
    });
  }
});

test('T-14.2: totals come from COBOL counts, paging echoes the request', async () => {
  const users = await request(app).get('/v1/users').set('Authorization', bearer());
  assert.equal(users.body.meta.total, 2);
  assert.deepEqual(users.body.meta, { ...users.body.meta, limit: 20, offset: 0 });
  const policies = await request(app).get('/v1/payments/policies').set('Authorization', bearer()).query({ limit: '1' });
  assert.equal(policies.body.meta.total, 3);
  assert.equal(policies.body.meta.limit, 1);
  assert.equal(policies.body.data[0].currency, 'USD');
  const accounts = await request(app).get('/v1/accounts').set('Authorization', bearer());
  assert.equal(accounts.body.meta.total, null);
  assert.equal(accounts.body.data[0].accountRef, 'R-1');
});
