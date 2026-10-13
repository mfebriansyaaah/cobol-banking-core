import { test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { buildApp } from '../src/app.js';
import { resetMetrics, recordRequest, metricsText } from '../src/observability.js';

test('metricsText renders recorded counters', () => {
  resetMetrics();
  recordRequest({ method: 'GET', route: '/health', status: 200 });
  recordRequest({ method: 'GET', route: '/health', status: 200 });
  const text = metricsText();
  assert.match(text, /gateway_requests_total\{method="GET",route="\/health",status="200"\} 2/);
});

test('a request is logged with an id, route and latency', async () => {
  resetMetrics();
  const lines = [];
  const app = buildApp({ logger: (line) => lines.push(line) });
  const res = await request(app).get('/health');
  assert.equal(res.status, 200);
  assert.ok(res.headers['x-request-id']);

  const line = lines.find((l) => l.event === 'http_request');
  assert.ok(line, 'request line emitted');
  assert.equal(line.method, 'GET');
  assert.equal(line.route, '/health');
  assert.equal(line.status, 200);
  assert.equal(typeof line.durationMs, 'number');
  // The raw path (which may contain an email) is not logged.
  assert.equal(line.path, undefined);
});

test('/metrics requires a token', async () => {
  const app = buildApp();
  const denied = await request(app).get('/metrics');
  assert.equal(denied.status, 401);
});

test('/metrics serves counters to an authenticated caller', async () => {
  resetMetrics();
  const app = buildApp();
  const em = `obs_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Obs User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: s.body.data[1] });
  const login = await request(app).post('/auth/login').send({ email: em, password: 'secret123' });

  await request(app).get('/health');
  const m = await request(app).get('/metrics').set('Authorization', `Bearer ${login.body.token}`);
  assert.equal(m.status, 200);
  assert.match(m.text, /gateway_requests_total/);
  assert.match(m.text, /route="\/health"/);
});
