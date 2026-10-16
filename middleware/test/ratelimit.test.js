import { test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { createRateLimiter, memoryStore } from '../src/rateLimit.js';

// Configure a tiny window before importing the app.
process.env.RATE_LIMIT_MAX = '2';
process.env.RATE_LIMIT_WINDOW_MS = '60000';
process.env.API_RATE_LIMIT_MAX = '2';
process.env.API_RATE_LIMIT_WINDOW_MS = '60000';
const { buildApp } = await import('../src/app.js');
const app = buildApp();

test('auth endpoints are rate limited past the configured max', async () => {
  // Invalid bodies fail validation (400) but still consume the window.
  const first = await request(app).post('/auth/login').send({});
  const second = await request(app).post('/auth/login').send({});
  const third = await request(app).post('/auth/login').send({});
  assert.equal(first.status, 400);
  assert.equal(second.status, 400);
  assert.equal(third.status, 429);
  assert.equal(third.body.error, 'RATE_LIMITED');
});

test('non-auth endpoints are rate limited past the configured max', async () => {
  // Missing tokens fail auth (401) but still consume the window.
  const first = await request(app).get('/users');
  const second = await request(app).get('/users');
  const third = await request(app).get('/users');
  assert.equal(first.status, 401);
  assert.equal(second.status, 401);
  assert.equal(third.status, 429);
  assert.equal(third.body.error, 'RATE_LIMITED');
});

test('the health probe responds', async () => {
  const fresh = buildApp();
  const res = await request(fresh).get('/health');
  assert.equal(res.status, 200);
});

test('a shared store enforces one limit across instances', async () => {
  const store = memoryStore();
  const instanceA = createRateLimiter({ store, windowMs: 60000, max: 2 });
  const instanceB = createRateLimiter({ store, windowMs: 60000, max: 2 });
  const makeRes = () => {
    const r = { headers: {} };
    r.set = (k, v) => { r.headers[k] = v; };
    r.status = (c) => { r.code = c; return r; };
    r.json = (b) => { r.body = b; return r; };
    return r;
  };
  const req = { ip: '1.2.3.4' };
  const noop = () => {};

  await instanceA(req, makeRes(), noop); // 1
  await instanceB(req, makeRes(), noop); // 2 (other instance, same store)
  const third = makeRes();
  await instanceA(req, third, noop); // 3 -> limited
  assert.equal(third.code, 429);
  assert.equal(third.body.error, 'RATE_LIMITED');
  assert.ok(third.headers['Retry-After']);
});

test('public probes are rate limited', async () => {
  const saved = process.env.API_RATE_LIMIT_MAX;
  process.env.API_RATE_LIMIT_MAX = '1';
  const fresh = buildApp();
  assert.equal((await request(fresh).get('/health')).status, 200);
  assert.equal((await request(fresh).get('/ready')).status, 429);
  if (saved === undefined) delete process.env.API_RATE_LIMIT_MAX; else process.env.API_RATE_LIMIT_MAX = saved;
});

test('a broken store fails open instead of taking the API down', async () => {
  const broken = { hit: async () => { throw new Error('store down'); } };
  const limit = createRateLimiter({ store: broken, windowMs: 60000, max: 1 });
  let proceeded = false;
  const res = { headers: {} };
  res.set = (k, v) => { res.headers[k] = v; };
  res.status = (c) => { res.code = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  await limit({ ip: '9.9.9.9' }, res, () => { proceeded = true; });
  assert.equal(proceeded, true);
  assert.equal(res.code, undefined);
});
