// Worker-pool integration: enable the pool, drive real requests through the
// app, and confirm the same workers are reused (file mode is the default; this
// file opts in via COBOL_POOL_SIZE before the first invoke).
process.env.COBOL_POOL_SIZE = '2';

import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';

const { buildApp } = await import('../src/app.js');
const { getPool, resetPool } = await import('../src/pool.js');
const { getVerificationCode } = await import('./support.js');

const app = buildApp();
after(() => resetPool());

test('the worker pool serves requests end to end', async () => {
  const health = await request(app).get('/health');
  assert.equal(health.status, 200);
  assert.equal(health.body.status, 'ok');

  const pool = getPool();
  assert.ok(pool, 'the pool is enabled');
  assert.ok(pool.stats().size >= 1, 'at least one worker is running');

  const em = `gw_pool_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Pool User', dob: '1990-01-01' });
  assert.equal(s.status, 200);
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const login = await request(app).post('/auth/login').send({ email: em, password: 'secret123' });
  assert.equal(login.status, 200);
  assert.ok(login.body.token);
});

test('workers are reused across requests', async () => {
  const pool = getPool();
  const size = pool.stats().size;
  for (let i = 0; i < 3; i += 1) {
    assert.equal((await request(app).get('/health')).status, 200);
  }
  assert.equal(pool.stats().size, size, 'no extra workers spawned');
  assert.equal(pool.stats().queued, 0, 'queue drained');
});
