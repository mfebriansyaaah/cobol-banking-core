import { test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';

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

test('health is not rate limited', async () => {
  const res = await request(app).get('/health');
  assert.equal(res.status, 200);
});
